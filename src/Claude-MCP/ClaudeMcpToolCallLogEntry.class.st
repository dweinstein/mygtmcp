Class {
	#name : 'ClaudeMcpToolCallLogEntry',
	#superclass : 'Object',
	#instVars : [
		'index',
		'dictionary'
	],
	#category : 'Claude-MCP',
	#package : 'Claude-MCP'
}

{ #category : 'instance creation' }
ClaudeMcpToolCallLogEntry class >> index: anInteger dictionary: aDictionary [
	^ self new
		index: anInteger;
		dictionary: aDictionary;
		yourself
]

{ #category : 'printing' }
ClaudeMcpToolCallLogEntry >> argumentSummary [
	^ (ClaudeMcpToolCallPayload title: 'Arguments' value: self arguments) summary
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> arguments [
	^ self valueAt: #arguments ifAbsent: [ Dictionary new ]
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> argumentsPayload [
	^ ClaudeMcpToolCallPayload title: 'Arguments' value: self arguments
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> detailsAssociations [
	^ {
		'Index' -> self index.
		'Tool' -> self toolName.
		'Error' -> self isError.
		'Arguments' -> self argumentsPayload.
		'Result' -> self resultPayload.
		'Request' -> self request.
		'Response' -> self response }
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> dictionary [
	^ dictionary
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> dictionary: aDictionary [
	dictionary := aDictionary
]

{ #category : 'printing' }
ClaudeMcpToolCallLogEntry >> errorLabel [
	self isError ifFalse: [ ^ '' ].
	^ 'Yes'
]

{ #category : 'views' }
ClaudeMcpToolCallLogEntry >> gtArgumentsFor: aView [
	<gtView>
	^ aView forward
		title: 'Arguments';
		priority: 2;
		object: [ self argumentsPayload ];
		view: #gtItemsFor:
]

{ #category : 'views' }
ClaudeMcpToolCallLogEntry >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 1;
		items: [ self detailsAssociations ];
		column: 'Field' text: #key width: 110;
		column: 'Value' text: [ :each | self previewFor: each value ];
		send: [ :each | each value ]
]

{ #category : 'views' }
ClaudeMcpToolCallLogEntry >> gtRawDictionaryFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Raw dictionary';
		priority: 10;
		items: [ self dictionary associations ];
		column: 'Key' text: #key width: 120;
		column: 'Value' text: [ :each | self previewFor: each value ];
		send: [ :each | each value ]
]

{ #category : 'views' }
ClaudeMcpToolCallLogEntry >> gtResultFor: aView [
	<gtView>
	^ aView forward
		title: 'Result';
		priority: 3;
		object: [ self resultPayload ];
		view: #gtItemsFor:
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> index [
	^ index
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> index: anInteger [
	index := anInteger
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> isError [
	^ self valueAt: #isError ifAbsent: [ false ]
]

{ #category : 'printing' }
ClaudeMcpToolCallLogEntry >> previewFor: anObject [
	anObject ifNil: [ ^ '' ].
	(anObject isKindOf: ClaudeMcpToolCallPayload) ifTrue: [ ^ anObject summary ].
	^ anObject asString truncateTo: 200
]

{ #category : 'printing' }
ClaudeMcpToolCallLogEntry >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: ' #';
		nextPutAll: self index asString;
		nextPutAll: ' ';
		nextPutAll: self toolName asString
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> request [
	^ self valueAt: #request ifAbsent: [ nil ]
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> response [
	^ self valueAt: #response ifAbsent: [ nil ]
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> result [
	^ self valueAt: #result ifAbsent: [ Dictionary new ]
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> resultPayload [
	^ ClaudeMcpToolCallPayload title: 'Result' value: self result
]

{ #category : 'printing' }
ClaudeMcpToolCallLogEntry >> resultSummary [
	^ (ClaudeMcpToolCallPayload title: 'Result' value: self result) summary
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> toolName [
	^ self valueAt: #toolName ifAbsent: [ '?' ]
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntry >> valueAt: aKey ifAbsent: aBlock [
	^ self dictionary at: aKey ifAbsent: aBlock
]
