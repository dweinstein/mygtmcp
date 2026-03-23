Class {
	#name : 'MyGtMcpServer',
	#superclass : 'GtMcpServer',
	#instVars : [
		'resourceTemplates'
	],
	#category : 'Claude-MCP',
	#package : 'Claude-MCP'
}

{ #category : 'private' }
MyGtMcpServer >> acceptedNotificationResponse [
	| notificationResponse |
	notificationResponse := ZnResponse new.
	notificationResponse statusLine: (ZnStatusLine code: 202).
	^ notificationResponse
]

{ #category : 'accessing' }
MyGtMcpServer >> addResourceTemplate: aTemplate [
	resourceTemplates add: aTemplate
]

{ #category : 'accessing' }
MyGtMcpServer >> clearResourceTemplates [
	resourceTemplates removeAll
]

{ #category : 'private' }
MyGtMcpServer >> cursorStartFor: aJsonRpc [
	| cursor |
	cursor := aJsonRpc params at: 'cursor' ifAbsent: [ nil ].
	cursor ifNil: [ ^ 1 ].
	^ [ cursor asInteger ] on: Error do: [ 1 ]
]

{ #category : 'private' }
MyGtMcpServer >> defaultListPageSize [
	^ 100
]

{ #category : 'mcp' }
MyGtMcpServer >> getCapabilities [
	| capabilities |
	capabilities := super getCapabilities.
	(resources isNotEmpty or: [ resourceTemplates isNotEmpty ])
		ifTrue: [ capabilities at: 'resources' put: Dictionary new ].
	^ capabilities
]

{ #category : 'mcp' }
MyGtMcpServer >> handleRequest: request [
        | jsonRpc response jsonRpcResult |
        request method = 'GET' ifTrue: [
                ^ (ZnResponse statusCode: 405)
                        headers: ZnHeaders defaultResponseHeaders;
                        yourself ].
        [ jsonRpc := GtMcpJsonRpc on: (STONJSON fromString: request entity contents) ]
                on: Error
                do: [ ^ ZnResponse badRequest: request ].
        [
                [
                        jsonRpcResult := self dispatch: jsonRpc
                ]
                        on: MyGtMcpJsonRpcError
                        do: [ :anError |
                                errors add: anError freeze.
                                jsonRpc id ifNil: [
                                        response := self acceptedNotificationResponse.
                                        history add: request -> response.
                                        ^ response ].
                                response := self jsonRpcErrorResponseFor: anError id: jsonRpc id.
                                history add: request -> response.
                                ^ response ]
        ]
                on: Error
                do: [ :anError |
                        errors add: anError freeze.
                        self isDebug ifTrue: [ anError signal ].
                        jsonRpcResult := {
                                'content' -> {{
                                        'type' -> 'text'.
                                        'text' -> ('Error: ', anError class name, ' - ', anError messageText)
                                } asDictionary} asArray.
                                'isError' -> true
                        } asDictionary ].
        jsonRpc id ifNil: [
                response := self acceptedNotificationResponse.
                history add: request -> response.
                ^ response ].
        response := (GtMcpJsonRpc new
                id: jsonRpc id;
                result: jsonRpcResult) asZnResponse.
        history add: request -> response.
        ^ response
]

{ #category : 'mcp' }
MyGtMcpServer >> handleResourcesList: aJsonRpc [
	| entries |
	entries := resources items collect: [ :each | self resourceDictionaryFor: each ].
	^ self paginatedItems: entries for: aJsonRpc resultKey: 'resources'
]

{ #category : 'mcp' }
MyGtMcpServer >> handleResourcesRead: aJsonRpc [
	| uri resource association text |
	uri := self validateResourceUri: (aJsonRpc params at: 'uri' ifAbsent: [ nil ]).
	resource := self resourceForUri: uri.
	resource ifNotNil: [
		[ text := resource contents ]
			on: Error
			do: [ :error |
				(error isKindOf: MyGtMcpJsonRpcError)
					ifTrue: [ error pass ].
				MyGtMcpJsonRpcError
					signalCode: -32603
					message: 'Internal error'
					data: {'uri' -> uri. 'error' -> error messageText} asDictionary ].
		^ {'contents' -> { (self resourceContentsDictionaryFor: resource uri: uri text: text) }} asDictionary ].
	association := self templateAssociationForUri: uri.
	association ifNil: [ self resourceNotFoundFor: uri ].
	[ text := association key contentsForVariables: association value ]
		on: Error
		do: [ :error |
			(error isKindOf: MyGtMcpJsonRpcError)
				ifTrue: [ error pass ].
			MyGtMcpJsonRpcError
				signalCode: -32603
				message: 'Internal error'
				data: {'uri' -> uri. 'error' -> error messageText} asDictionary ].
	^ {'contents' -> { (self templateContentsDictionaryFor: association key uri: uri text: text) }} asDictionary
]

{ #category : 'mcp' }
MyGtMcpServer >> handleResourcesTemplatesList: aJsonRpc [
	| entries |
	entries := resourceTemplates collect: [ :each | each asMcpDictionary ].
	^ self paginatedItems: entries for: aJsonRpc resultKey: 'resourceTemplates'
]

{ #category : 'initialization' }
MyGtMcpServer >> initialize [
	super initialize.
	resourceTemplates := OrderedCollection new
]

{ #category : 'private' }
MyGtMcpServer >> jsonRpcErrorResponseFor: anError id: anId [
	| payload |
	payload := Dictionary new.
	payload at: 'jsonrpc' put: '2.0'.
	payload at: 'id' put: anId.
	payload at: 'error' put: {
		'code' -> anError code.
		'message' -> anError messageText.
		'data' -> anError data } asDictionary.
	^ ZnResponse ok: (ZnStringEntity json: (NeoJSONWriter toString: payload))
]

{ #category : 'private' }
MyGtMcpServer >> paginatedItems: aCollection for: aJsonRpc resultKey: aString [
	| items start stop page nextCursor dictionary |
	items := aCollection asArray.
	start := self cursorStartFor: aJsonRpc.
	start := start max: 1.
	stop := (start + self defaultListPageSize - 1) min: items size.
	page := start > items size
		ifTrue: [ #() ]
		ifFalse: [ items copyFrom: start to: stop ].
	nextCursor := stop < items size ifTrue: [ (stop + 1) asString ] ifFalse: [ nil ].
	dictionary := Dictionary new.
	dictionary at: aString put: page.
	nextCursor ifNotNil: [ dictionary at: 'nextCursor' put: nextCursor ].
	^ dictionary
]

{ #category : 'private' }
MyGtMcpServer >> resourceContentsDictionaryFor: aResource uri: aUri text: aText [
	| dictionary |
	dictionary := {
		'uri' -> aUri.
		'name' -> aResource name.
		'title' -> aResource title.
		'mimeType' -> aResource mimeType asString.
		'text' -> aText } asDictionary.
	(aResource respondsTo: #annotations)
		ifTrue: [ | annotations |
			annotations := aResource annotations.
			annotations ifNotNil: [ dictionary at: 'annotations' put: annotations ] ].
	^ dictionary
]

{ #category : 'private' }
MyGtMcpServer >> resourceDictionaryFor: aResource [
	^ {
		'uri' -> aResource uri.
		'name' -> aResource name.
		'title' -> aResource title.
		'description' -> aResource description.
		'mimeType' -> aResource mimeType asString } asDictionary
]

{ #category : 'private' }
MyGtMcpServer >> resourceForUri: aUri [
	^ resources detect: [ :each | each uri = aUri ] ifNone: [ nil ]
]

{ #category : 'private' }
MyGtMcpServer >> resourceNotFoundFor: aUri [
	MyGtMcpJsonRpcError
		signalCode: -32002
		message: 'Resource not found'
		data: {'uri' -> aUri} asDictionary
]

{ #category : 'accessing' }
MyGtMcpServer >> resourceTemplates [
	^ resourceTemplates
]

{ #category : 'private' }
MyGtMcpServer >> templateAssociationForUri: aUri [
	resourceTemplates do: [ :each |
		| variables |
		variables := each matchesUri: aUri.
		variables ifNotNil: [ ^ each -> variables ] ].
	^ nil
]

{ #category : 'private' }
MyGtMcpServer >> templateContentsDictionaryFor: aTemplate uri: aUri text: aText [
	| dictionary |
	dictionary := {
		'uri' -> aUri.
		'name' -> aTemplate name.
		'title' -> aTemplate title.
		'mimeType' -> aTemplate mimeType asString.
		'text' -> aText } asDictionary.
	aTemplate annotations ifNotNil: [ dictionary at: 'annotations' put: aTemplate annotations ].
	^ dictionary
]

{ #category : 'private' }
MyGtMcpServer >> validateResourceUri: aString [
	| url |
	aString ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'uri' -> aString} asDictionary ].
	[ url := ZnUrl fromString: aString ]
		on: Error
		do: [ :error |
			MyGtMcpJsonRpcError
				signalCode: -32002
				message: 'Resource not found'
				data: {'uri' -> aString. 'error' -> error messageText} asDictionary ].
	url scheme = 'gtmcp'
		ifFalse: [ MyGtMcpJsonRpcError
				signalCode: -32002
				message: 'Resource not found'
				data: {'uri' -> aString} asDictionary ].
	^ aString
]
