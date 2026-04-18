Class {
	#name : 'MyGtMcpResource',
	#superclass : 'Object',
	#instVars : [
		'mcpServer'
	],
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'extension' }
MyGtMcpResource class >> allMcpExtensionResourceClasses [
	^ (self allSubclasses select: [ :each | each isMcpExtensionResource ])
		sort: [ :a :b | a name < b name ]
]

{ #category : 'completion' }
MyGtMcpResource class >> filteredCompletionValues: aCollection matching: aQuery [
	"Generic completion filter: prefix matches first, then substring matches, case-insensitive."
	| query normalizedCandidates prefixMatches substringMatches ordered |
	query := aQuery ifNil: [ '' ] ifNotNil: [ aQuery asString asLowercase ].
	normalizedCandidates := ((aCollection collect: [ :each | each asString ]) asSet asArray)
		asSortedCollection: [ :a :b | a asLowercase < b asLowercase ].
	query isEmpty ifTrue: [ ^ normalizedCandidates asArray ].
	prefixMatches := OrderedCollection new.
	substringMatches := OrderedCollection new.
	normalizedCandidates do: [ :each |
		| lower |
		lower := each asLowercase.
		(lower beginsWith: query)
			ifTrue: [ prefixMatches add: each ]
			ifFalse: [ (lower includesSubstring: query) ifTrue: [ substringMatches add: each ] ] ].
	ordered := OrderedCollection new.
	ordered addAll: prefixMatches.
	ordered addAll: substringMatches.
	^ ordered asArray
]

{ #category : 'extension' }
MyGtMcpResource class >> isMcpExtensionResource [
	"Subclasses defined in separate extension packages should override this to return true.
	When ClaudeMcpServer>>#addAllExtensionResources runs, every subclass answering true here is
	auto-registered on top of the built-in resources. Default false so built-ins (registered
	explicitly in addAllResources) are not double-registered."
	^ false
]

{ #category : 'testing' }
MyGtMcpResource class >> isTemplate [
	^ self uriTemplate includes: ${
]

{ #category : 'accessing' }
MyGtMcpResource class >> mimeType [
	^ 'text/plain'
]

{ #category : 'instance creation' }
MyGtMcpResource class >> on: aMcpServer [
	^ self new
		mcpServer: aMcpServer;
		yourself
]

{ #category : 'completion' }
MyGtMcpResource class >> requiredCompletionContextValueNamed: aName from: aDictionary [
	| value |
	value := aDictionary at: aName ifAbsent: [
		MyGtMcpJsonRpcError
			signalCode: -32602
			message: 'Invalid params'
			data: {'reason' -> 'Missing required context argument'. 'name' -> aName} asDictionary ].
	^ value asString
]

{ #category : 'accessing' }
MyGtMcpResource class >> resourceDescription [
	self subclassResponsibility
]

{ #category : 'accessing' }
MyGtMcpResource class >> resourceName [
	self subclassResponsibility
]

{ #category : 'accessing' }
MyGtMcpResource class >> resourceTitle [
	^ self resourceName
]

{ #category : 'accessing' }
MyGtMcpResource class >> uriTemplate [
	"Return the URI pattern for this resource. Literal for singletons (e.g. 'gtmcp://lepiter/databases'),
	templated with {var} segments for parameterized resources (e.g. 'gtmcp://lepiter/page/{uid}')."
	self subclassResponsibility
]

{ #category : 'completion' }
MyGtMcpResource >> completionValuesForArgument: argument context: context [
	"Return an array of completion suggestions for argument (a Dictionary with 'name' and 'value')
	given context (a Dictionary of already-bound argument values).
	Default: no completion — subclasses that want to support it override this."
	^ nil
]

{ #category : 'contents' }
MyGtMcpResource >> contentsForVariables: aDictionary [
	"Return the text contents for this resource. aDictionary is empty for singleton resources,
	or contains the decoded variable values for templated resources."
	self subclassResponsibility
]

{ #category : 'preview' }
MyGtMcpResource >> exampleVariables [
	"Return a Dictionary of example variable values for inspector preview, or nil if none available.
	Singleton resources return nil (no variables needed); templated resources should return a dict
	that binds every {var} in the uriTemplate to a live example value."
	^ nil
]

{ #category : 'testing' }
MyGtMcpResource >> isTemplate [
	^ self class isTemplate
]

{ #category : 'accessing' }
MyGtMcpResource >> mcpServer [
	^ mcpServer
]

{ #category : 'accessing' }
MyGtMcpResource >> mcpServer: aMcpServer [
	mcpServer := aMcpServer
]

{ #category : 'accessing' }
MyGtMcpResource >> mimeType [
	^ self class mimeType
]

{ #category : 'rendering' }
MyGtMcpResource >> renderLepiterPage: aPage [
	"Render a Lepiter page to its MCP text form: header fields + each child snippet.
	Shared by resources that return a full page's content (LepiterPageResource, LepiterDatabaseTitleResource)."
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Page: '; nextPutAll: aPage title; lf.
		stream nextPutAll: 'UID: '; nextPutAll: aPage uid asString; lf.
		stream nextPutAll: 'Database: '; nextPutAll: aPage database databaseName; lf.
		stream nextPutAll: 'Snippets: '; nextPutAll: aPage children size asString; lf; lf.
		aPage children withIndexDo: [ :snippet :index |
			| content |
			content := snippet isTextualSnippet
				ifTrue: [ snippet string copyReplaceAll: String cr with: String lf ]
				ifFalse: [ '(non-textual snippet)' ].
			stream nextPutAll: index asString; nextPutAll: '. ['; nextPutAll: snippet class name; nextPutAll: ']'; lf.
			stream nextPutAll: '   UID: '; nextPutAll: snippet uid asString; lf.
			stream nextPutAll: '   Content: '; nextPutAll: content; lf; lf ] ]
]

{ #category : 'accessing' }
MyGtMcpResource >> resourceDescription [
	^ self class resourceDescription
]

{ #category : 'accessing' }
MyGtMcpResource >> resourceName [
	^ self class resourceName
]

{ #category : 'accessing' }
MyGtMcpResource >> resourceTitle [
	^ self class resourceTitle
]

{ #category : 'accessing' }
MyGtMcpResource >> uriTemplate [
	^ self class uriTemplate
]
