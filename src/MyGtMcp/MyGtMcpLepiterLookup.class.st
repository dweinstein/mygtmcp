Class {
	#name : 'MyGtMcpLepiterLookup',
	#superclass : 'Object',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'completion' }
MyGtMcpLepiterLookup class >> completionValuesForDatabaseTitle: aQuery context: aContext [
	| databaseUuid database titles |
	databaseUuid := MyGtMcpResource requiredCompletionContextValueNamed: 'databaseUuid' from: aContext.
	database := self databaseByUuidString: databaseUuid.
	titles := database pages collect: #title.
	^ MyGtMcpResource filteredCompletionValues: titles matching: aQuery
]

{ #category : 'completion' }
MyGtMcpLepiterLookup class >> completionValuesForDatabaseUuid: aQuery [
	^ MyGtMcpResource
		filteredCompletionValues: (self logicalDatabase databases collect: #uuidString)
		matching: aQuery
]

{ #category : 'completion' }
MyGtMcpLepiterLookup class >> completionValuesForPageUid: aQuery [
	^ MyGtMcpResource
		filteredCompletionValues: (self logicalDatabase pages collect: [ :each | each uid asString ])
		matching: aQuery
]

{ #category : 'completion' }
MyGtMcpLepiterLookup class >> completionValuesForSnippetUid: aQuery [
	| values |
	values := OrderedCollection new.
	self logicalDatabase snippetsDo: [ :snippet | values add: snippet uid asString ].
	^ MyGtMcpResource filteredCompletionValues: values matching: aQuery
]

{ #category : 'completion' }
MyGtMcpLepiterLookup class >> completionValuesForTitle: aQuery [
	^ MyGtMcpResource
		filteredCompletionValues: (self logicalDatabase pages collect: #title)
		matching: aQuery
]

{ #category : 'lookup' }
MyGtMcpLepiterLookup class >> databaseByUuidString: aString [
	| database |
	database := self logicalDatabase databases
		detect: [ :each | each uuidString = aString ]
		ifNone: [ nil ].
	database ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'databaseUuid' -> aString} asDictionary ].
	^ database
]

{ #category : 'accessing' }
MyGtMcpLepiterLookup class >> logicalDatabase [
	^ LeDatabasesRegistry default defaultLogicalDatabase
]

{ #category : 'lookup' }
MyGtMcpLepiterLookup class >> pageByUidString: aString [
	| uuid page |
	[ uuid := UUID fromString: aString ]
		on: Error
		do: [ MyGtMcpJsonRpcError
				signalCode: -32002
				message: 'Resource not found'
				data: {'pageUid' -> aString} asDictionary ].
	self logicalDatabase databases do: [ :database |
		page := [ database pageByUuid: uuid ] on: Error do: [ nil ].
		page ifNotNil: [ ^ page ] ].
	MyGtMcpJsonRpcError
		signalCode: -32002
		message: 'Resource not found'
		data: {'pageUid' -> aString} asDictionary
]

{ #category : 'lookup' }
MyGtMcpLepiterLookup class >> pagesMatchingTitle: aTitle [
	| matches |
	matches := OrderedCollection new.
	self logicalDatabase databases do: [ :database |
		| page |
		page := [ database pageNamed: aTitle ] on: Error do: [ nil ].
		page ifNotNil: [ matches add: page ] ].
	^ matches asArray
]

{ #category : 'lookup' }
MyGtMcpLepiterLookup class >> snippetByUidString: aString [
	| snippet uid |
	uid := LeUID new uidString: aString.
	[ snippet := self logicalDatabase snippetWithUID: uid ]
		on: Error
		do: [ snippet := nil ].
	snippet ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'snippetUid' -> aString} asDictionary ].
	^ snippet
]
