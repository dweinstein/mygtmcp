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
MyGtMcpServer >> completionResultValues: aCollection total: anInteger [
	| values cappedValues |
	values := aCollection asArray.
	cappedValues := values size > 100 ifTrue: [ values copyFrom: 1 to: 100 ] ifFalse: [ values ].
	^ {'completion' -> {'values' -> cappedValues. 'total' -> anInteger. 'hasMore' -> (anInteger > cappedValues size)} asDictionary} asDictionary
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

{ #category : 'handlers' }
MyGtMcpServer >> dispatch: aJsonRpc [
	"Unknown methods answer JSON-RPC -32601 so clients treat the capability as absent."
	| selector |
	selector := (#handle
		, ((aJsonRpc method replaceAllRegex: '[^a-zA-Z]' with: ' ') asCamelCase asSymbol asMutator)) asSymbol.
	(self respondsTo: selector) ifFalse: [
		MyGtMcpJsonRpcError
			signalCode: -32601
			message: 'Method not found: ' , aJsonRpc method
			data: nil ].
	^ self perform: selector withArguments: { aJsonRpc }
]

{ #category : 'mcp' }
MyGtMcpServer >> getCapabilities [
	| capabilities |
	capabilities := super getCapabilities.
	(resources isNotEmpty or: [ resourceTemplates isNotEmpty ])
		ifTrue: [ capabilities at: 'resources' put: Dictionary new ].
	capabilities at: 'completions' put: Dictionary new.
	^ capabilities
]

{ #category : 'mcp' }
MyGtMcpServer >> handleCompletionComplete: aJsonRpc [
	| template argument context values |
	template := self validatedCompletionRefFrom: aJsonRpc.
	argument := self validatedCompletionArgumentFrom: aJsonRpc forTemplate: template.
	context := self validatedCompletionContextFrom: aJsonRpc.
	[ values := ClaudeMcpServer default
		completionValuesForResourceTemplateUri: template uriTemplate
		argument: argument
		context: context ]
		on: Error
		do: [ :error |
			(error isKindOf: MyGtMcpJsonRpcError)
				ifTrue: [ error pass ].
			MyGtMcpJsonRpcError
				signalCode: -32603
				message: 'Internal error'
				data: {'uriTemplate' -> template uriTemplate. 'argument' -> (argument at: 'name'). 'error' -> error messageText} asDictionary ].
	^ self completionResultValues: values total: values size
]

{ #category : 'handlers' }
MyGtMcpServer >> handlePing: aJsonRpc [
	"Clients health-check with ping and expect an empty result."
	^ Dictionary new
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
MyGtMcpServer >> invalidParams: aString data: aDictionary [
	MyGtMcpJsonRpcError
		signalCode: -32602
		message: aString
		data: aDictionary
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

{ #category : 'private' }
MyGtMcpServer >> resourceTemplateForUriTemplate: aString [
	^ resourceTemplates
		detect: [ :each | each uriTemplate = aString ]
		ifNone: [ self invalidParams: 'Invalid params' data: {'uriTemplate' -> aString} asDictionary ]
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

{ #category : 'private' }
MyGtMcpServer >> validatedCompletionArgumentFrom: aJsonRpc forTemplate: aTemplate [
	| argument name value |
	argument := aJsonRpc params at: 'argument' ifAbsent: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'Missing argument'} asDictionary ].
	(argument isKindOf: Dictionary) ifFalse: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'argument must be an object'} asDictionary ].
	name := argument at: 'name' ifAbsent: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'Missing argument.name'} asDictionary ].
	(aTemplate templateVariables includes: name) ifFalse: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'Unknown argument for template'. 'name' -> name. 'uriTemplate' -> aTemplate uriTemplate} asDictionary ].
	value := argument at: 'value' ifAbsent: [ '' ].
	^ {'name' -> name. 'value' -> value asString} asDictionary
]

{ #category : 'private' }
MyGtMcpServer >> validatedCompletionContextFrom: aJsonRpc [
	| context arguments |
	context := aJsonRpc params at: 'context' ifAbsent: [ ^ Dictionary new ].
	(context isKindOf: Dictionary) ifFalse: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'context must be an object'} asDictionary ].
	arguments := context at: 'arguments' ifAbsent: [ Dictionary new ].
	(arguments isKindOf: Dictionary) ifFalse: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'context.arguments must be an object'} asDictionary ].
	^ arguments
]

{ #category : 'private' }
MyGtMcpServer >> validatedCompletionRefFrom: aJsonRpc [
	| ref refType uri |
	ref := aJsonRpc params at: 'ref' ifAbsent: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'Missing ref'} asDictionary ].
	(ref isKindOf: Dictionary) ifFalse: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'ref must be an object'} asDictionary ].
	refType := ref at: 'type' ifAbsent: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'Missing ref.type'} asDictionary ].
	refType = 'ref/resource' ifFalse: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'Only ref/resource is supported'. 'type' -> refType} asDictionary ].
	uri := ref at: 'uri' ifAbsent: [
		self invalidParams: 'Invalid params' data: {'reason' -> 'Missing ref.uri'} asDictionary ].
	^ self resourceTemplateForUriTemplate: uri
]
