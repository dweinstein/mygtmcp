Class {
	#name : 'MyGtMcpGitRepositoryResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpGitRepositoryResource class >> resourceDescription [
	^ 'Read summary information for one loaded Git repository.'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoryResource class >> resourceName [
	^ 'Git repository'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoryResource class >> uriTemplate [
	^ 'gtmcp://git/repository/{name}'
]

{ #category : 'completion' }
MyGtMcpGitRepositoryResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'name' ifTrue: [
		^ MyGtMcpGitLookup completionValuesForRepositoryName: (argument at: 'value') ].
	^ nil
]

{ #category : 'contents' }
MyGtMcpGitRepositoryResource >> contentsForVariables: aDictionary [
	| repository changedNodes |
	repository := MyGtMcpGitLookup repositoryNamed: (aDictionary at: 'name').
	changedNodes := MyGtMcpGitLookup changedNodesForRepository: repository.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Repository: '; nextPutAll: repository name; lf.
		stream nextPutAll: 'Branch: '; nextPutAll: repository branchName; lf.
		stream nextPutAll: 'Head: '; nextPutAll: repository headDescription; lf.
		stream nextPutAll: 'Path: '; nextPutAll: repository location pathString; lf.
		stream nextPutAll: 'Changed nodes: '; nextPutAll: changedNodes size asString ]
]

{ #category : 'preview' }
MyGtMcpGitRepositoryResource >> exampleVariables [
	| repos |
	repos := MyGtMcpGitLookup repositories.
	repos isEmpty ifTrue: [ ^ nil ].
	^ {'name' -> repos anyOne name} asDictionary
]
