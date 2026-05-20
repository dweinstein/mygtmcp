Class {
	#name : 'MyGtMcpGitRepositoryChangesResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpGitRepositoryChangesResource class >> resourceDescription [
	^ 'Read a changed-files summary for one loaded Git repository.'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoryChangesResource class >> resourceName [
	^ 'Git repository changes'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoryChangesResource class >> uriTemplate [
	^ 'gtmcp://git/repository/{name}/changes'
]

{ #category : 'completion' }
MyGtMcpGitRepositoryChangesResource >> completionValuesForArgument: argument context: context [
	(argument at: 'name') = 'name' ifTrue: [
		^ MyGtMcpGitLookup completionValuesForRepositoryName: (argument at: 'value') ].
	^ nil
]

{ #category : 'accessing' }
MyGtMcpGitRepositoryChangesResource >> contentsForVariables: aDictionary [
	| repository lines |
	repository := MyGtMcpGitLookup repositoryNamed: (aDictionary at: 'name').
	lines := MyGtMcpGitLookup changeSummaryLinesForRepository: repository.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Changes for '; nextPutAll: repository name; lf; lf.
		lines isEmpty
			ifTrue: [ stream nextPutAll: '(no changes)' ]
			ifFalse: [ lines do: [ :line | stream nextPutAll: line; lf ] ] ]
]

{ #category : 'preview' }
MyGtMcpGitRepositoryChangesResource >> exampleVariables [
	| repos |
	repos := MyGtMcpGitLookup repositories.
	repos isEmpty ifTrue: [ ^ nil ].
	^ {'name' -> repos anyOne name} asDictionary
]
