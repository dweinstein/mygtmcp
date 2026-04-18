Class {
	#name : 'MyGtMcpLepiterPagesResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterPagesResource class >> resourceDescription [
	^ 'List Lepiter pages across the current logical database.'
]

{ #category : 'accessing' }
MyGtMcpLepiterPagesResource class >> resourceName [
	^ 'Lepiter pages'
]

{ #category : 'accessing' }
MyGtMcpLepiterPagesResource class >> uriTemplate [
	^ 'gtmcp://lepiter/pages'
]

{ #category : 'contents' }
MyGtMcpLepiterPagesResource >> contentsForVariables: aDictionary [
	| pages |
	pages := MyGtMcpLepiterLookup logicalDatabase pages
		asSortedCollection: [ :a :b | a title < b title ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Pages: '; nextPutAll: pages size asString; lf; lf.
		pages do: [ :page |
			stream
				nextPutAll: page uid asString;
				nextPutAll: ' | ';
				nextPutAll: page title;
				nextPutAll: ' | ';
				nextPutAll: page database databaseName;
				lf ] ]
]
