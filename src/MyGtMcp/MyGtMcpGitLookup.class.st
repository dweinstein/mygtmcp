Class {
	#name : 'MyGtMcpGitLookup',
	#superclass : 'Object',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'lookup' }
MyGtMcpGitLookup class >> changedNodesForRepository: aRepository [
	^ aRepository workingCopyDiff tree allChildren
		reject: [ :each | each value class name = 'IceNoModification' ]
]

{ #category : 'completion' }
MyGtMcpGitLookup class >> completionValuesForRepositoryName: aQuery [
	^ MyGtMcpResource
		filteredCompletionValues: (self repositories collect: #name)
		matching: aQuery
]

{ #category : 'accessing' }
MyGtMcpGitLookup class >> repositories [
	^ IceRepository registry asSortedCollection: [ :a :b | a name < b name ]
]

{ #category : 'lookup' }
MyGtMcpGitLookup class >> repositoryNamed: aName [
	| repository |
	repository := self repositories detect: [ :each | each name = aName ] ifNone: [ nil ].
	repository ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'repositoryName' -> aName} asDictionary ].
	^ repository
]
