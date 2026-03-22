Class {
	#name : 'MyGtMcpUpdateSnippetTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpUpdateSnippetTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'snippetUid' -> {'type' -> 'string'} asDictionary.
			'content' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('snippetUid' 'content').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpUpdateSnippetTool class >> toolDescription [
	^ 'Updates a Lepiter snippet content by UID. Only works for textual snippets.'
]

{ #category : 'accessing' }
MyGtMcpUpdateSnippetTool class >> toolName [
	^ 'updateSnippet'
]

{ #category : 'execution' }
MyGtMcpUpdateSnippetTool >> executeWithArguments: arguments [
	| db snippet uid content |
	uid := LeUID new uidString: (arguments at: 'snippetUid').
	content := arguments at: 'content'.
	db := LeDatabasesRegistry default defaultLogicalDatabase.
	[ snippet := db snippetWithUID: uid ]
		on: Error
		do: [ :e | snippet := nil ].
	snippet ifNil: [ ^ 'Snippet not found for UID: ', (arguments at: 'snippetUid') ].
	snippet isTextualSnippet ifFalse: [ ^ 'Error: Cannot update non-textual snippet (', snippet class name, ')' ].
	snippet updateString: content.
	^ 'Updated snippet: ', snippet uid asString
]
