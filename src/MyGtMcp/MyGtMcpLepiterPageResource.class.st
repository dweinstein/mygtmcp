Class {
	#name : 'MyGtMcpLepiterPageResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpLepiterPageResource class >> resourceDescription [
	^ 'Read a Lepiter page by page UUID.'
]

{ #category : 'accessing' }
MyGtMcpLepiterPageResource class >> resourceName [
	^ 'Lepiter page'
]

{ #category : 'accessing' }
MyGtMcpLepiterPageResource class >> uriTemplate [
	^ 'gtmcp://lepiter/page/{uid}'
]

{ #category : 'completion' }
MyGtMcpLepiterPageResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'uid' ifTrue: [
		^ MyGtMcpLepiterLookup completionValuesForPageUid: (argument at: 'value') ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpLepiterPageResource >> contentsForVariables: aDictionary [
	| page |
	page := MyGtMcpLepiterLookup pageByUidString: (aDictionary at: 'uid').
	^ self renderLepiterPage: page
]

{ #category : 'preview' }
MyGtMcpLepiterPageResource >> exampleVariables [
	| pages |
	pages := MyGtMcpLepiterLookup logicalDatabase pages.
	pages isEmpty ifTrue: [ ^ nil ].
	^ {'uid' -> pages anyOne uid asString} asDictionary
]
