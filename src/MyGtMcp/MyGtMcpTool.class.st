Class {
	#name : 'MyGtMcpTool',
	#superclass : 'Object',
	#instVars : [
		'mcpServer'
	],
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'extension' }
MyGtMcpTool class >> allMcpExtensionToolClasses [
	"Return every MyGtMcpTool subclass that opts in to auto-registration via
	isMcpExtensionTool. Classes are sorted by name for deterministic ordering."
	^ (self allSubclasses select: [ :each | each isMcpExtensionTool ])
		sort: [ :a :b | a name < b name ]
]

{ #category : 'schema' }
MyGtMcpTool class >> inputSchema [
	self subclassResponsibility
]

{ #category : 'extension' }
MyGtMcpTool class >> isMcpExtensionTool [
	"Subclasses defined in separate extension packages should override this to return true.
	When ClaudeMcpServer>>#addAllExtensionTools runs, every subclass answering true here is
	auto-registered on top of the built-in tools. Default is false so the base class and
	the built-in tools (registered explicitly in addAllTools) are not double-registered."
	^ false
]

{ #category : 'instance creation' }
MyGtMcpTool class >> on: aMcpServer [
	^ self new
		mcpServer: aMcpServer;
		yourself
]

{ #category : 'testing' }
MyGtMcpTool class >> shouldTruncateResult [
	"Whether results returned by this tool should be length-capped by the MCP server's
	maxLength (default 2000 chars). Subclasses whose output is bounded and curated
	(e.g. a knowledge index summary) may override this to return false and opt out
	of truncation. Leave the default true for tools that return arbitrary content
	(evaluate, readPage, etc.) where unbounded output could flood the transport."
	^ true
]

{ #category : 'accessing' }
MyGtMcpTool class >> toolDescription [
	self subclassResponsibility
]

{ #category : 'accessing' }
MyGtMcpTool class >> toolName [
	self subclassResponsibility
]

{ #category : 'accessing' }
MyGtMcpTool >> allowedParameters [
	^ (self inputSchema at: 'properties' ifAbsent: [ Dictionary new ]) keys asSet
]

{ #category : 'accessing' }
MyGtMcpTool >> description [
	^ self class toolDescription
]

{ #category : 'execution' }
MyGtMcpTool >> executeWithArguments: arguments [
	self subclassResponsibility
]

{ #category : 'lepiter lookup' }
MyGtMcpTool >> findDatabaseFrom: arguments [
	"Return the specific database if databaseId is provided, otherwise the default logical database."
	| databaseId |
	databaseId := arguments at: 'databaseId' ifAbsent: [ nil ].
	databaseId ifNil: [ ^ LeDatabasesRegistry default defaultLogicalDatabase ].
	^ LeDatabasesRegistry default defaultLogicalDatabase databases
		detect: [ :db | db uuidString = databaseId ]
		ifNone: [ self error: 'Database not found for ID: ' , databaseId ]
]

{ #category : 'lepiter lookup' }
MyGtMcpTool >> findPageFrom: arguments [
	"Look up a page by pageId (string36) or pageTitle, optionally scoped by databaseId (string36).
	Returns the page or nil if not found."
	| db pageId pageTitle |
	db := self findDatabaseFrom: arguments.
	pageId := arguments at: 'pageId' ifAbsent: [ nil ].
	pageTitle := arguments at: 'pageTitle' ifAbsent: [ nil ].
	(pageId isNil and: [ pageTitle isNil ])
		ifTrue: [ self error: 'Either pageId or pageTitle must be provided' ].
	pageId ifNotNil: [
		| uuid |
		uuid := UUID fromString36: pageId.
		db pagesDo: [ :each | each uid = uuid ifTrue: [ ^ each ] ].
		^ nil ].
	db pagesDo: [ :each | each title = pageTitle ifTrue: [ ^ each ] ].
	^ nil
]

{ #category : 'gt-views' }
MyGtMcpTool >> gtParametersFor: aView [
	<gtView>
	self parameters ifEmpty: [ ^ aView empty ].
	^ aView columnedList
		title: 'Parameters';
		priority: 20;
		items: [ self parameterRows ];
		column: 'Name' text: [ :each | each at: 'name' ];
		column: 'Required' text: [ :each | (each at: 'required') ifTrue: [ 'yes' ] ifFalse: [ 'no' ] ] width: 70;
		column: 'Type' text: [ :each | each at: 'type' ] width: 90;
		column: 'Allowed Values' text: [ :each | each at: 'enum' ] weight: 1;
		column: 'Default' text: [ :each | each at: 'default' ] width: 90;
		column: 'Description' text: [ :each | each at: 'description' ] weight: 2
]

{ #category : 'gt-views' }
MyGtMcpTool >> gtSchemaFor: aView [
	<gtView>
	^ aView forward
		title: 'Schema';
		priority: 21;
		object: [ self inputSchema ]
]

{ #category : 'gt-views' }
MyGtMcpTool >> gtSummaryFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Summary';
		priority: 19;
		items: [ {
			'Name' -> self name.
			'Required parameters' -> self requiredParameters size asString.
			'Optional parameters' -> (self parameters size - self requiredParameters size) asString.
			'All parameters' -> self parametersDescription } ];
		column: 'Property' text: #key;
		column: 'Value' text: #value
]

{ #category : 'gt-views' }
MyGtMcpTool >> gtViewsFor: aView [
	<gtView>
	^ aView empty
]

{ #category : 'accessing' }
MyGtMcpTool >> inputSchema [
	^ self class inputSchema
]

{ #category : 'accessing' }
MyGtMcpTool >> mcpServer [
	^ mcpServer
]

{ #category : 'accessing' }
MyGtMcpTool >> mcpServer: aMcpServer [
	mcpServer := aMcpServer
]

{ #category : 'accessing' }
MyGtMcpTool >> name [
	^ self class toolName
]

{ #category : 'private' }
MyGtMcpTool >> parameterRows [
	^ self parameters collect: [ :each |
		| schema enumValues |
		schema := self parameterSchemaFor: each.
		enumValues := schema at: 'enum' ifAbsent: [ #() ].
		Dictionary newFrom: {
			'name' -> each.
			'required' -> (self requiredParameters includes: each).
			'type' -> (schema at: 'type' ifAbsent: [ '' ]).
			'enum' -> (enumValues
				ifEmpty: [ '' ]
				ifNotEmpty: [ ', ' join: (enumValues collect: [ :value | value asString ]) ]).
			'default' -> ((schema at: 'default' ifAbsent: [ '' ]) asString).
			'description' -> (schema at: 'description' ifAbsent: [ '' ]) } ]
]

{ #category : 'private' }
MyGtMcpTool >> parameterSchemaFor: aParameterName [
	^ (self inputSchema at: 'properties' ifAbsent: [ Dictionary new ])
		at: aParameterName
		ifAbsent: [ Dictionary new ]
]

{ #category : 'accessing' }
MyGtMcpTool >> parameters [
	^ self allowedParameters asArray sorted
]

{ #category : 'accessing' }
MyGtMcpTool >> parametersDescription [
	self parameters ifEmpty: [ ^ '(none)' ].
	^ ', ' join: (self parameters collect: [ :each |
		(self requiredParameters includes: each)
			ifTrue: [ each asString ]
			ifFalse: [ each asString, '?' ] ])
]

{ #category : 'execution' }
MyGtMcpTool >> performToolCall: aGtLlmFunctionToolCall [
	| arguments result |
	arguments := aGtLlmFunctionToolCall arguments ifNil: [ Dictionary new ].
	self validateArguments: arguments.
	result := self executeWithArguments: arguments.
	^ self truncateResult: result
]

{ #category : 'accessing' }
MyGtMcpTool >> requiredParameters [
	^ (self inputSchema at: 'required' ifAbsent: [ #() ]) asSet
]

{ #category : 'private' }
MyGtMcpTool >> textContent: aString [
	^ {
		'type' -> 'text'.
		'text' -> aString
	} asDictionary
]

{ #category : 'private' }
MyGtMcpTool >> truncateContentItems: contentArray [
	^ contentArray collect: [ :item |
		(item at: 'type') = 'text'
			ifTrue: [
				item at: 'text' put: (self mcpServer truncate: (item at: 'text')).
				item ]
			ifFalse: [ item ] ]
]

{ #category : 'executing' }
MyGtMcpTool >> truncateResult: result [
	"Apply maxLength truncation unless the tool's class has opted out.
	Content-item arrays get per-item text truncation; plain results go through
	the server's global truncate:. When truncation is disabled, the result is
	passed through unchanged (String or array-of-dicts)."
	self class shouldTruncateResult ifFalse: [ ^ result ].
	(result isArray and: [ result allSatisfy: #isDictionary ])
		ifTrue: [ ^ self truncateContentItems: result ].
	^ self mcpServer truncate: result asString
]

{ #category : 'validation' }
MyGtMcpTool >> validateArguments: arguments [
	| actualKeys unknownKeys missingKeys |
	arguments isDictionary ifFalse: [ self error: 'Tool arguments must be an object' ].
	actualKeys := arguments keys asSet.
	unknownKeys := actualKeys difference: self allowedParameters.
	unknownKeys ifNotEmpty: [
		self error: 'Unknown arguments for ', self name, ': ', (', ' join: unknownKeys asArray sorted) ].
	missingKeys := self requiredParameters reject: [ :each | arguments includesKey: each ].
	missingKeys ifNotEmpty: [
		self error: 'Missing required arguments for ', self name, ': ', (', ' join: missingKeys asArray sorted) ]
]
