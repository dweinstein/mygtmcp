Class {
	#name : 'MyGtMcpLepiterDatabaseResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterDatabaseResource class >> resourceDescription [
	^ 'Read summary information for a Lepiter database by UUID.'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabaseResource class >> resourceName [
	^ 'Lepiter database'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabaseResource class >> uriTemplate [
	^ 'gtmcp://lepiter/database/{databaseUuid}'
]

{ #category : 'completion' }
MyGtMcpLepiterDatabaseResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'databaseUuid' ifTrue: [
		^ MyGtMcpLepiterLookup completionValuesForDatabaseUuid: (argument at: 'value') ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpLepiterDatabaseResource >> contentsForVariables: aDictionary [
	| database |
	database := MyGtMcpLepiterLookup databaseByUuidString: (aDictionary at: 'databaseUuid').
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Database: '; nextPutAll: database databaseName; lf.
		stream nextPutAll: 'UUID: '; nextPutAll: database uuidString; lf.
		stream nextPutAll: 'Pages: '; nextPutAll: database pages size asString ]
]

{ #category : 'preview' }
MyGtMcpLepiterDatabaseResource >> exampleVariables [
	| databases |
	databases := MyGtMcpLepiterLookup logicalDatabase databases.
	databases isEmpty ifTrue: [ ^ nil ].
	^ {'databaseUuid' -> databases anyOne uuidString} asDictionary
]
