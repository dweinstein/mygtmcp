Class {
	#name : 'MyGtMcpReadSnippetTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpReadSnippetTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'snippetUid' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('snippetUid').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpReadSnippetTool class >> toolDescription [
	^ 'Reads a specific Lepiter snippet by UID. Returns full content.'
]

{ #category : 'accessing' }
MyGtMcpReadSnippetTool class >> toolName [
	^ 'readSnippet'
]

{ #category : 'execution' }
MyGtMcpReadSnippetTool >> executeWithArguments: arguments [
	| db snippet uid |
	uid := LeUID new uidString: (arguments at: 'snippetUid').
	db := LeDatabasesRegistry default defaultLogicalDatabase.
	[ snippet := db snippetWithUID: uid ]
		on: Error
		do: [ :e | snippet := nil ].
	snippet ifNil: [ ^ 'Snippet not found for UID: ', (arguments at: 'snippetUid') ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Type: '; nextPutAll: snippet class name; cr.
		stream nextPutAll: 'UID: '; nextPutAll: snippet uid asString; cr; cr.
		stream nextPutAll: 'Content:'; cr.
		stream nextPutAll: (snippet isTextualSnippet ifTrue: [ snippet string ] ifFalse: [ '(non-textual snippet)' ]) ]
]
