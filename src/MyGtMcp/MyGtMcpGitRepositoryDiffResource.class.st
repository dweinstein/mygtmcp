Class {
	#name : 'MyGtMcpGitRepositoryDiffResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpGitRepositoryDiffResource class >> resourceDescription [
	^ 'Read a unified textual diff for one loaded Git repository.'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoryDiffResource class >> resourceName [
	^ 'Git repository diff'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoryDiffResource class >> uriTemplate [
	^ 'gtmcp://git/repository/{name}/diff'
]

{ #category : 'completion' }
MyGtMcpGitRepositoryDiffResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'name' ifTrue: [
		^ MyGtMcpGitLookup completionValuesForRepositoryName: (argument at: 'value') ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpGitRepositoryDiffResource >> contentsForVariables: aDictionary [
	| repository changedNodes |
	repository := MyGtMcpGitLookup repositoryNamed: (aDictionary at: 'name').
	changedNodes := MyGtMcpGitLookup changedNodesForRepository: repository.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Diff for '; nextPutAll: repository name; lf; lf.
		changedNodes isEmpty
			ifTrue: [ stream nextPutAll: '(no changes)' ]
			ifFalse: [ changedNodes do: [ :node |
				stream nextPutAll: (self patchTextForNode: node); lf; lf ] ] ]
]

{ #category : 'preview' }
MyGtMcpGitRepositoryDiffResource >> exampleVariables [
	| repos |
	repos := MyGtMcpGitLookup repositories.
	repos isEmpty ifTrue: [ ^ nil ].
	^ {'name' -> repos anyOne name} asDictionary
]

{ #category : 'private' }
MyGtMcpGitRepositoryDiffResource >> patchTextForNode: aNode [
	| operation path oldText newText patch |
	operation := aNode value.
	path := aNode path asString.
	oldText := [ operation rightContents ] on: Error do: [ '' ].
	newText := [ operation leftContents ] on: Error do: [ '' ].
	patch := DiffBuilder buildPatchFrom: oldText to: newText.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'diff --gtmcp a/'; nextPutAll: path; nextPutAll: ' b/'; nextPutAll: path; lf.
		stream nextPutAll: '--- a/'; nextPutAll: path; lf.
		stream nextPutAll: '+++ b/'; nextPutAll: path; lf.
		stream nextPutAll: patch patch ]
]
