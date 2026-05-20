Class {
	#name : 'ClaudeMcpToolCallPayload',
	#superclass : 'Object',
	#instVars : [
		'title',
		'value'
	],
	#category : 'Claude-MCP',
	#package : 'Claude-MCP'
}

{ #category : 'instance creation' }
ClaudeMcpToolCallPayload class >> title: aString value: anObject [
	^ self new
		title: aString;
		value: anObject;
		yourself
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> arrayItems [
	| counter |
	counter := 0.
	^ self value collect: [ :each |
		counter := counter + 1.
		counter asString -> each ]
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> dictionaryItems [
	^ self value associations sorted: [ :a :b |
		a key asString < b key asString ]
]

{ #category : 'printing' }
ClaudeMcpToolCallPayload >> dictionarySummary [
	self value ifEmpty: [ ^ '' ].
	^ (', ' join: (self value associations collect: [ :each |
		each key asString , ': ' , (self previewFor: each value) ])) truncateTo: 160
]

{ #category : 'views' }
ClaudeMcpToolCallPayload >> gtItemsFor: aView [
	<gtView>
	^ aView columnedList
		title: self title asString;
		priority: 1;
		items: [ self items ];
		column: 'Key' text: #key width: 140;
		column: 'Value' text: [ :each | self previewFor: each value ];
		send: [ :each | self objectFor: each value named: each key asString ]
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> items [
	self value ifNil: [ ^ #() ].
	self value isDictionary ifTrue: [ ^ self dictionaryItems ].
	self value isArray ifTrue: [ ^ self arrayItems ].
	^ { 'Value' -> self value }
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> objectFor: anObject named: aString [
	anObject ifNil: [ ^ nil ].
	(anObject isDictionary or: [ anObject isArray ])
		ifTrue: [ ^ self class title: aString value: anObject ].
	^ anObject
]

{ #category : 'printing' }
ClaudeMcpToolCallPayload >> previewFor: anObject [
	anObject ifNil: [ ^ '' ].
	anObject isDictionary ifTrue: [ ^ anObject size asString , ' keys' ].
	anObject isArray ifTrue: [ ^ anObject size asString , ' items' ].
	^ anObject asString truncateTo: 80
]

{ #category : 'printing' }
ClaudeMcpToolCallPayload >> printOn: aStream [
	aStream
		nextPutAll: self title asString;
		nextPutAll: ' (';
		nextPutAll: self summary;
		nextPutAll: ')'
]

{ #category : 'printing' }
ClaudeMcpToolCallPayload >> summary [
	self value ifNil: [ ^ '' ].
	self value isDictionary ifTrue: [ ^ self dictionarySummary ].
	self value isArray ifTrue: [ ^ self value size asString , ' items' ].
	^ self value asString truncateTo: 160
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> title [
	^ title
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> title: aString [
	title := aString
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> value [
	^ value
]

{ #category : 'accessing' }
ClaudeMcpToolCallPayload >> value: anObject [
	value := anObject
]
