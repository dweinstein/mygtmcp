Class {
	#name : 'MyGtMcpLepiterDatabasesResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterDatabasesResource class >> resourceDescription [
	^ 'List the Lepiter databases available in the current logical database.'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabasesResource class >> resourceName [
	^ 'Lepiter databases'
]

{ #category : 'accessing' }
MyGtMcpLepiterDatabasesResource class >> uriTemplate [
	^ 'gtmcp://lepiter/databases'
]

{ #category : 'contents' }
MyGtMcpLepiterDatabasesResource >> contentsForVariables: aDictionary [
	| databases |
	databases := MyGtMcpLepiterLookup logicalDatabase databases
		asSortedCollection: [ :a :b | a databaseName < b databaseName ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Lepiter databases: '; nextPutAll: databases size asString; lf; lf.
		databases do: [ :database |
			stream
				nextPutAll: database uuidString;
				nextPutAll: ' | ';
				nextPutAll: database databaseName;
				nextPutAll: ' | pages: ';
				nextPutAll: database pages size asString;
				lf ] ]
]
