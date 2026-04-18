Class {
	#name : 'MyGtMcpLepiterSnippetResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterSnippetResource class >> resourceDescription [
	^ 'Read a Lepiter snippet by snippet UID.'
]

{ #category : 'accessing' }
MyGtMcpLepiterSnippetResource class >> resourceName [
	^ 'Lepiter snippet'
]

{ #category : 'accessing' }
MyGtMcpLepiterSnippetResource class >> uriTemplate [
	^ 'gtmcp://lepiter/snippet/{uid}'
]

{ #category : 'completion' }
MyGtMcpLepiterSnippetResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'uid' ifTrue: [
		^ MyGtMcpLepiterLookup completionValuesForSnippetUid: (argument at: 'value') ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpLepiterSnippetResource >> contentsForVariables: aDictionary [
	| snippet content |
	snippet := MyGtMcpLepiterLookup snippetByUidString: (aDictionary at: 'uid').
	content := snippet isTextualSnippet
		ifTrue: [ snippet string copyReplaceAll: String cr with: String lf ]
		ifFalse: [ '(non-textual snippet)' ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Type: '; nextPutAll: snippet class name; lf.
		stream nextPutAll: 'UID: '; nextPutAll: snippet uid asString; lf; lf.
		stream nextPutAll: 'Content:'; lf.
		stream nextPutAll: content ]
]

{ #category : 'preview' }
MyGtMcpLepiterSnippetResource >> exampleVariables [
	| pages page |
	pages := MyGtMcpLepiterLookup logicalDatabase pages.
	pages isEmpty ifTrue: [ ^ nil ].
	page := pages detect: [ :p | p children notEmpty ] ifNone: [ nil ].
	page ifNil: [ ^ nil ].
	^ {'uid' -> page children first uid asString} asDictionary
]
