Class {
	#name : 'MyGtMcpAddSnippetTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpAddSnippetTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'pageTitle' -> {
				'type' -> 'string'.
				'description' -> 'Lepiter page title'
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
		'required' -> #('pageTitle' 'content').
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

{ #category : 'execution' }
MyGtMcpAddSnippetTool >> executeWithArguments: arguments [
	| db page content snippetType snippet |
	db := LeDatabasesRegistry default defaultLogicalDatabase.
	page := db pageNamed: (arguments at: 'pageTitle') ifAbsent: [
		| newPage |
		newPage := LePage named: (arguments at: 'pageTitle').
		db addPage: newPage.
		newPage ].
	content := arguments at: 'content'.
	snippetType := arguments at: 'snippetType' ifAbsent: [ 'text' ].
	snippet := snippetType = 'pharo'
		ifTrue: [ LePharoSnippet code: content ]
		ifFalse: [ LeTextSnippet string: content ].
	page addSnippet: snippet.
	^ 'Added snippet: ', snippet uid asString
]
