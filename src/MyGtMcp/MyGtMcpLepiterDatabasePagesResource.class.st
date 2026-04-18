Class {
	#name : 'MyGtMcpLepiterDatabasePagesResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterDatabasePagesResource class >> resourceDescription [
	^ 'List pages inside one Lepiter database by UUID.'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabasePagesResource class >> resourceName [
	^ 'Lepiter database pages'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabasePagesResource class >> uriTemplate [
	^ 'gtmcp://lepiter/database/{databaseUuid}/pages'
]

{ #category : 'completion' }
MyGtMcpLepiterDatabasePagesResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'databaseUuid' ifTrue: [
		^ MyGtMcpLepiterLookup completionValuesForDatabaseUuid: (argument at: 'value') ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpLepiterDatabasePagesResource >> contentsForVariables: aDictionary [
	| database pages |
	database := MyGtMcpLepiterLookup databaseByUuidString: (aDictionary at: 'databaseUuid').
	pages := database pages asSortedCollection: [ :a :b | a title < b title ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Pages in database: '; nextPutAll: database databaseName; lf.
		stream nextPutAll: 'Database UUID: '; nextPutAll: database uuidString; lf.
		stream nextPutAll: 'Pages: '; nextPutAll: pages size asString; lf; lf.
		pages do: [ :page |
			stream nextPutAll: page uid asString; nextPutAll: ' | '; nextPutAll: page title; lf ] ]
]

{ #category : 'preview' }
MyGtMcpLepiterDatabasePagesResource >> exampleVariables [
	| databases |
	databases := MyGtMcpLepiterLookup logicalDatabase databases.
	databases isEmpty ifTrue: [ ^ nil ].
	^ {'databaseUuid' -> databases anyOne uuidString} asDictionary
]
