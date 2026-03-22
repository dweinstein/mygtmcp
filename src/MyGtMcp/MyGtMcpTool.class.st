Class {
	#name : 'MyGtMcpTool',
	#superclass : 'Object',
	#instVars : [
		'mcpServer'
	],
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpTool class >> inputSchema [
	self subclassResponsibility
]

{ #category : 'instance creation' }
MyGtMcpTool class >> on: aMcpServer [
	^ self new
		mcpServer: aMcpServer;
		yourself
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

{ #category : 'private' }
MyGtMcpTool >> truncateResult: result [
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
