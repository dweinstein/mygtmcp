Class {
	#name : 'MyGtMcpReadPageTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpReadPageTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'pageTitle' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('pageTitle').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpReadPageTool class >> toolDescription [
	^ 'Reads a Lepiter page by title. Returns snippets with their UIDs, types, and content.'
]

{ #category : 'accessing' }
MyGtMcpReadPageTool class >> toolName [
	^ 'readPage'
]

{ #category : 'execution' }
MyGtMcpReadPageTool >> executeWithArguments: arguments [
	| db page |
	db := LeDatabasesRegistry default defaultLogicalDatabase.
	page := db pages
		detect: [ :each | each title = (arguments at: 'pageTitle') ]
		ifNone: [ nil ].
	page ifNil: [ ^ 'Page not found: ', (arguments at: 'pageTitle') ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Page: '; nextPutAll: page title; cr.
		stream nextPutAll: 'UID: '; nextPutAll: page uid asString; cr.
		stream nextPutAll: 'Snippets: '; nextPutAll: page children size asString; cr; cr.
		page children withIndexDo: [ :snippet :idx |
			stream nextPutAll: idx asString; nextPutAll: '. '.
			stream nextPutAll: '['; nextPutAll: snippet class name; nextPutAll: ']'; cr.
			stream nextPutAll: '   UID: '; nextPutAll: snippet uid asString; cr.
			stream nextPutAll: '   Content: ';
				nextPutAll: (snippet isTextualSnippet ifTrue: [ snippet string ] ifFalse: [ '(non-textual snippet)' ]);
				cr; cr ] ]
]
