Class {
	#name : 'MyGtMcpListPagesTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpListPagesTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'query' -> {
				'type' -> 'string'.
				'description' -> 'Optional page-title substring filter'
			} asDictionary
		} asDictionary.
		'required' -> #().
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpListPagesTool class >> toolDescription [
	^ 'Lists Lepiter pages with their titles and UIDs. The optional query parameter filters pages by case-insensitive substring match on the title. Without a query, lists all pages (may be truncated).'
]

{ #category : 'accessing' }
MyGtMcpListPagesTool class >> toolName [
	^ 'listPages'
]

{ #category : 'execution' }
MyGtMcpListPagesTool >> executeWithArguments: arguments [
	| db pages query |
	db := LeDatabasesRegistry default defaultLogicalDatabase.
	query := arguments at: 'query' ifAbsent: [ nil ].
	pages := db pages sorted: [ :a :b | a title < b title ].
	(query notNil and: [ query isNotEmpty ]) ifTrue: [
		pages := pages select: [ :page |
			page title asLowercase includesSubstring: query asLowercase ] ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Pages ('; nextPutAll: pages size asString; nextPutAll: ' results)'; cr; cr.
		pages do: [ :page |
			stream nextPutAll: page uid asString; nextPutAll: ' | '; nextPutAll: page title; cr ] ]
]
