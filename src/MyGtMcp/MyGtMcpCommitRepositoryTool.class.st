Class {
	#name : 'MyGtMcpCommitRepositoryTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpCommitRepositoryTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'name' -> {
				'type' -> 'string'.
				'description' -> 'Repository name as registered in IceRepository registry.'
			} asDictionary.
			'message' -> {
				'type' -> 'string'.
				'description' -> 'Commit message.'
			} asDictionary.
			'confirm' -> {
				'type' -> 'boolean'.
				'default' -> false.
				'description' -> 'When true, actually commit. When false or omitted, returns a dry-run preview without committing.'
			} asDictionary
		} asDictionary.
		'required' -> #('name' 'message').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpCommitRepositoryTool class >> toolDescription [
	^ 'Commit all current changes on a registered Iceberg repository. Defaults to dry-run: returns a preview summary without committing. Pass confirm: true to actually commit. Picks up in-image code changes and tracked or untracked Lepiter files under lepiter/.'
]

{ #category : 'accessing' }
MyGtMcpCommitRepositoryTool class >> toolName [
	^ 'commitRepository'
]

{ #category : 'execution' }
MyGtMcpCommitRepositoryTool >> commitAllChangesForRepository: repository message: message [
	| diff index parentCommits newCommit |
	repository workingCopy validateCanCommit.
	diff := repository workingCopyDiff.
	index := repository index.
	diff tree allChildren isEmpty ifFalse: [
		index
			updateDiskWorkingCopy: diff;
			updateIndex: diff ].
	self stageLepiterChangesForRepository: repository index: index.
	index isEmpty ifTrue: [ IceNothingToCommit signal ].
	parentCommits := repository workingCopy workingCopyState referenceCommits
		reject: [ :each | each isNoCommit ].
	newCommit := repository commitIndexWithMessage: message andParents: parentCommits.
	repository workingCopy referenceCommit: newCommit.
	repository workingCopy refreshDirtyPackages.
	^ newCommit
]

{ #category : 'execution' }
MyGtMcpCommitRepositoryTool >> executeWithArguments: arguments [
	| name message confirm repository packageChanges lepiterChanges totalChanges firstLine commit |
	name := (arguments at: 'name') asString.
	message := (arguments at: 'message') asString.
	message trimmed isEmpty ifTrue: [
		MyGtMcpJsonRpcError
			signalCode: -32602
			message: 'Invalid params'
			data: {'reason' -> 'Message must be non-empty'} asDictionary ].
	confirm := arguments at: 'confirm' ifAbsent: [ false ].
	repository := MyGtMcpGitLookup repositoryNamed: name.
	packageChanges := MyGtMcpGitLookup changedNodesForRepository: repository.
	lepiterChanges := MyGtMcpGitLookup lepiterDeltasForRepository: repository.
	totalChanges := packageChanges size + lepiterChanges size.
	firstLine := (message lines detect: [ :ln | ln trimmed notEmpty ] ifNone: [ message ]) trimmed.
	confirm = true ifFalse: [
		^ String streamContents: [ :stream |
			stream nextPutAll: 'Dry run - not committed.'; lf.
			stream nextPutAll: 'Repository: '; nextPutAll: repository name;
				nextPutAll: ' (branch: '; nextPutAll: repository branchName; nextPutAll: ')'; lf.
			stream nextPutAll: totalChanges asString; nextPutAll: ' changes'; lf.
			stream nextPutAll: 'Package changes: '; nextPutAll: packageChanges size asString; lf.
			stream nextPutAll: 'Lepiter changes: '; nextPutAll: lepiterChanges size asString; lf.
			stream nextPutAll: 'Message: '; nextPutAll: firstLine; lf; lf.
			stream nextPutAll: 'Re-invoke with confirm: true to commit.'; lf.
			stream nextPutAll: 'Or read gtmcp://git/repository/'; nextPutAll: repository name;
				nextPutAll: '/changes for per-file summary.' ] ].
	totalChanges = 0 ifTrue: [ ^ self noChangesResponseForRepository: repository ].
	[
		[ commit := self commitAllChangesForRepository: repository message: message ]
			on: IceNothingToCommit
			do: [ :ignored | ^ self noChangesResponseForRepository: repository ] ]
		on: IceError
		do: [ :anError |
			MyGtMcpJsonRpcError
				signalCode: -32000
				message: 'Commit failed'
				data: {
					'repository' -> repository name.
					'error' -> anError messageText } asDictionary ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Committed '; nextPutAll: (self shortHeadForRepository: repository); lf.
		stream nextPutAll: '  '; nextPutAll: firstLine; lf.
		stream nextPutAll: '  '; nextPutAll: totalChanges asString;
			nextPutAll: ' changes (packages: '; nextPutAll: packageChanges size asString;
			nextPutAll: ', lepiter: '; nextPutAll: lepiterChanges size asString;
			nextPutAll: ')'; lf.
		stream nextPutAll: '  Commits: 1' ]
]

{ #category : 'formatting' }
MyGtMcpCommitRepositoryTool >> noChangesResponseForRepository: repository [
	| shortSha |
	shortSha := repository head commit id first: (8 min: repository head commit id size).
	^ String streamContents: [ :stream |
		stream nextPutAll: 'No changes to commit.'; lf.
		stream nextPutAll: 'HEAD: '; nextPutAll: shortSha;
			nextPutAll: ' - ';
			nextPutAll: (repository head commit comment lines
				detect: [ :ln | ln trimmed notEmpty ] ifNone: [ '' ]) trimmed ]
]

{ #category : 'formatting' }
MyGtMcpCommitRepositoryTool >> shortHeadForRepository: repository [
	^ repository head commit id first: (8 min: repository head commit id size)
]

{ #category : 'execution' }
MyGtMcpCommitRepositoryTool >> stageLepiterChangesForRepository: repository index: index [
	(MyGtMcpGitLookup lepiterDeltasForRepository: repository) isEmpty ifTrue: [ ^ self ].
	index addPath: (RelativePath withAll: #('lepiter'))
]
