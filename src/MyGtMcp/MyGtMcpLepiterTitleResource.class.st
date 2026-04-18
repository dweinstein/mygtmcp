Class {
	#name : 'MyGtMcpLepiterTitleResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterTitleResource class >> resourceDescription [
	^ 'Resolve an exact Lepiter page title to matching page UUIDs across databases.'
]

{ #category : 'accessing' }
MyGtMcpLepiterTitleResource class >> resourceName [
	^ 'Lepiter title resolver'
]

{ #category : 'accessing' }
MyGtMcpLepiterTitleResource class >> uriTemplate [
	^ 'gtmcp://lepiter/title/{title}'
]

{ #category : 'completion' }
MyGtMcpLepiterTitleResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'title' ifTrue: [
		^ MyGtMcpLepiterLookup completionValuesForTitle: (argument at: 'value') ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpLepiterTitleResource >> contentsForVariables: aDictionary [
	| title matches |
	title := aDictionary at: 'title'.
	matches := MyGtMcpLepiterLookup pagesMatchingTitle: title.
	matches ifEmpty: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'title' -> title} asDictionary ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Title matches for: '; nextPutAll: title; lf; lf.
		matches do: [ :page |
			stream
				nextPutAll: page uid asString;
				nextPutAll: ' | ';
				nextPutAll: page title;
				nextPutAll: ' | ';
				nextPutAll: page database databaseName;
				lf ] ]
]

{ #category : 'preview' }
MyGtMcpLepiterTitleResource >> exampleVariables [
	| pages |
	pages := MyGtMcpLepiterLookup logicalDatabase pages.
	pages isEmpty ifTrue: [ ^ nil ].
	^ {'title' -> pages anyOne title} asDictionary
]
