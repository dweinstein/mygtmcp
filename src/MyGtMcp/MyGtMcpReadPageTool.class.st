Class {
	#name : 'MyGtMcpReadPageTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'tool definition' }
MyGtMcpReadPageTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'pageTitle' -> {
				'type' -> 'string'.
				'description' -> 'Page title to look up (optional if pageId is provided)'
			} asDictionary.
			'pageId' -> {
				'type' -> 'string'.
				'description' -> 'Page UUID as string36 (optional if pageTitle is provided)'
			} asDictionary.
			'databaseId' -> {
				'type' -> 'string'.
				'description' -> 'Database UUID as string36 to scope title lookup to a specific database'
			} asDictionary
		} asDictionary.
		'required' -> #().
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

{ #category : 'executing' }
MyGtMcpReadPageTool >> executeWithArguments: arguments [
	| page |
	page := self findPageFrom: arguments.
	page ifNil: [
		| pageId pageTitle |
		pageId := arguments at: 'pageId' ifAbsent: [ nil ].
		pageTitle := arguments at: 'pageTitle' ifAbsent: [ nil ].
		^ pageId
			ifNotNil: [ 'Page not found for ID: ' , pageId ]
			ifNil: [ 'Page not found: ' , pageTitle ] ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Page: '; nextPutAll: page title; cr.
		stream nextPutAll: 'UID: '; nextPutAll: page uid asString36; cr.
		stream nextPutAll: 'Database: '; nextPutAll: page database databaseName;
			nextPutAll: ' ('; nextPutAll: page database uuidString; nextPutAll: ')'; cr.
		stream nextPutAll: 'Snippets: '; nextPutAll: page children size asString; cr; cr.
		page children
			withIndexDo: [ :snippet :idx |
				stream nextPutAll: idx asString; nextPutAll: '. '.
				stream nextPutAll: '['; nextPutAll: snippet class name; nextPutAll: ']'; cr.
				stream nextPutAll: '   UID: '; nextPutAll: snippet uid asString; cr.
				stream
					nextPutAll: '   Content: ';
					nextPutAll: (snippet isTextualSnippet
						ifTrue: [ snippet string ]
						ifFalse: [ '(non-textual snippet)' ]);
					cr; cr ] ]
]
