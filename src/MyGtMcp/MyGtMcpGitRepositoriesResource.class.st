Class {
	#name : 'MyGtMcpGitRepositoriesResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpGitRepositoriesResource class >> resourceDescription [
	^ 'List the Git repositories currently loaded in the image.'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoriesResource class >> resourceName [
	^ 'Git repositories'
]

{ #category : 'accessing' }
MyGtMcpGitRepositoriesResource class >> uriTemplate [
	^ 'gtmcp://git/repositories'
]

{ #category : 'contents' }
MyGtMcpGitRepositoriesResource >> contentsForVariables: aDictionary [
	| repositories |
	repositories := MyGtMcpGitLookup repositories.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Repositories: '; nextPutAll: repositories size asString; lf; lf.
		repositories do: [ :repository |
			stream
				nextPutAll: repository name;
				nextPutAll: ' | ';
				nextPutAll: repository branchName;
				nextPutAll: ' | ';
				nextPutAll: repository location pathString;
				lf ] ]
]
