Class {
	#name : 'MyGtMcpAddSnippetTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'tool definition' }
MyGtMcpAddSnippetTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'pageTitle' -> {
				'type' -> 'string'.
				'description' -> 'Lepiter page title (optional if pageId is provided)'
			} asDictionary.
			'pageId' -> {
				'type' -> 'string'.
				'description' -> 'Page UUID as string36 (optional if pageTitle is provided)'
			} asDictionary.
			'databaseId' -> {
				'type' -> 'string'.
				'description' -> 'Database UUID as string36 to scope page lookup/creation'
			} asDictionary.
			'content' -> {
				'type' -> 'string'.
				'description' -> 'Snippet content'
			} asDictionary.
			'snippetType' -> {
				'type' -> 'string'.
				'description' -> 'Snippet type'.
				'enum' -> #('text' 'pharo')
			} asDictionary
		} asDictionary.
		'required' -> #('content').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpAddSnippetTool class >> toolDescription [
	^ 'Adds a new snippet to a Lepiter page. snippetType can be "text" or "pharo". Returns the new snippet UID.'
]

{ #category : 'accessing' }
MyGtMcpAddSnippetTool class >> toolName [
	^ 'addSnippet'
]

{ #category : 'executing' }
MyGtMcpAddSnippetTool >> executeWithArguments: arguments [
	| page content snippetType snippet db |
	page := self findPageFrom: arguments.
	page ifNil: [
		| pageTitle |
		pageTitle := arguments at: 'pageTitle' ifAbsent: [ nil ].
		pageTitle ifNil: [ self error: 'Page not found for pageId: ' , (arguments at: 'pageId') ].
		db := self findDatabaseFrom: arguments.
		page := LePage named: pageTitle.
		db addPage: page ].
	content := arguments at: 'content'.
	snippetType := arguments at: 'snippetType' ifAbsent: [ 'text' ].
	snippet := snippetType = 'pharo'
		ifTrue: [ LePharoSnippet code: content ]
		ifFalse: [ LeTextSnippet string: content ].
	page addSnippet: snippet.
	^ 'Added snippet: ' , snippet uid asString
]
