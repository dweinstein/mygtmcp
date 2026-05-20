Class {
	#name : 'MyGtMcpGitLookup',
	#superclass : 'Object',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'changes' }
MyGtMcpGitLookup class >> changeCountForRepository: aRepository [
	^ (self changedNodesForRepository: aRepository) size
		+ (self lepiterDeltasForRepository: aRepository) size
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> changeSummaryLinesForRepository: aRepository [
	| lines |
	lines := OrderedCollection new.
	(self changedNodesForRepository: aRepository)
		do: [ :node | lines add: (self packageChangeSummaryForNode: node) ].
	(self lepiterDeltasForRepository: aRepository)
		do: [ :delta | lines add: (self lepiterChangeSummaryForDelta: delta) ].
	^ lines asArray
]

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

{ #category : 'changes' }
MyGtMcpGitLookup class >> fallbackPatchForLepiterDelta: aDelta [
	| path contents |
	path := self pathForDelta: aDelta.
	contents := self fileContentsFor: aDelta newFile.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'diff --git a/'; nextPutAll: path; nextPutAll: ' b/'; nextPutAll: path; lf.
		stream nextPutAll: 'status: '; nextPutAll: aDelta status asString; lf.
		contents ifNotEmpty: [
			stream nextPutAll: '--- /dev/null'; lf.
			stream nextPutAll: '+++ b/'; nextPutAll: path; lf.
			stream nextPutAll: '@@'; lf.
			contents linesDo: [ :line |
				stream nextPut: $+; nextPutAll: line; lf ] ] ]
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> fileContentsFor: aFileReference [
	^ [ aFileReference exists
		ifTrue: [ aFileReference readStreamDo: [ :stream | stream contents ] ]
		ifFalse: [ '' ] ]
		on: Error
		do: [ :error | '' ]
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> isLepiterDelta: aDelta [
	^ self isLepiterPath: (self pathForDelta: aDelta)
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> isLepiterPath: aString [
	^ aString = 'lepiter' or: [ aString beginsWith: 'lepiter/' ]
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> lepiterChangeSummaryForDelta: aDelta [
	^ String streamContents: [ :stream |
		stream
			nextPutAll: (self pathForDelta: aDelta);
			nextPutAll: ' | Lepiter | ';
			nextPutAll: aDelta status asString ]
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> lepiterDeltasForRepository: aRepository [
	^ [ aRepository getDeltasForFullDiff select: [ :each | self isLepiterDelta: each ] ]
		on: Error
		do: [ :error | #() ]
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> lepiterPatchTextsForRepository: aRepository [
	| diff patches options |
	patches := OrderedCollection new.
	[ diff := LGitDiff of: aRepository.
	options := LGitDiffOptions defaults.
	options prim_flags: (LGitDiffOptionTypeEnum git_diff_include_untracked value
		bitXor: LGitDiffOptionTypeEnum git_diff_recurse_untracked_dirs value).
	aRepository repositoryHandle
		getDeltasFromHead: aRepository head
		options: options
		into: diff.
	1 to: diff numberOfDeltas do: [ :index |
		| delta patch |
		delta := GtGitDelta from: (diff deltaAt: index) in: aRepository.
		(self isLepiterDelta: delta) ifTrue: [
			patch := (diff patchAt: index) printDiff.
			patches add: (patch ifEmpty: [ self fallbackPatchForLepiterDelta: delta ]) ] ].
	^ patches asArray ]
		on: Error
		do: [ :error |
			^ (self lepiterDeltasForRepository: aRepository)
				collect: [ :delta | self fallbackPatchForLepiterDelta: delta ] ]
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> packageChangeSummaryForNode: aNode [
	^ String streamContents: [ :stream |
		stream
			nextPutAll: aNode path asString;
			nextPutAll: ' | Package | ';
			nextPutAll: aNode value class name ]
]

{ #category : 'changes' }
MyGtMcpGitLookup class >> pathForDelta: aDelta [
	| path |
	path := aDelta newFileRelative.
	path ifNil: [ path := aDelta oldFileRelative ].
	path ifNil: [ ^ '' ].
	^ path asString
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
