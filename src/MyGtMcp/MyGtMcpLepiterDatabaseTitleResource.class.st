Class {
	#name : 'MyGtMcpLepiterDatabaseTitleResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterDatabaseTitleResource class >> resourceDescription [
	^ 'Read a Lepiter page by exact title inside one database.'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabaseTitleResource class >> resourceName [
	^ 'Lepiter database title'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabaseTitleResource class >> uriTemplate [
	^ 'gtmcp://lepiter/database/{databaseUuid}/title/{title}'
]

{ #category : 'completion' }
MyGtMcpLepiterDatabaseTitleResource >> completionValuesForArgument: argument context: context [
	| name value |
	name := argument at: 'name'.
	value := argument at: 'value'.
	name = 'databaseUuid' ifTrue: [ ^ MyGtMcpLepiterLookup completionValuesForDatabaseUuid: value ].
	name = 'title' ifTrue: [ ^ MyGtMcpLepiterLookup completionValuesForDatabaseTitle: value context: context ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpLepiterDatabaseTitleResource >> contentsForVariables: aDictionary [
	| database title page |
	database := MyGtMcpLepiterLookup databaseByUuidString: (aDictionary at: 'databaseUuid').
	title := aDictionary at: 'title'.
	page := [ database pageNamed: title ] on: Error do: [ nil ].
	page ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'databaseUuid' -> database uuidString. 'title' -> title} asDictionary ].
	^ self renderLepiterPage: page
]

{ #category : 'preview' }
MyGtMcpLepiterDatabaseTitleResource >> exampleVariables [
	| databases database |
	databases := MyGtMcpLepiterLookup logicalDatabase databases.
	databases isEmpty ifTrue: [ ^ nil ].
	database := databases anyOne.
	database pages isEmpty ifTrue: [ ^ nil ].
	^ {'databaseUuid' -> database uuidString. 'title' -> database pages anyOne title} asDictionary
]
