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
	^ 'Commit all current changes on a registered Iceberg repository. Defaults to dry-run: returns a preview summary without committing. Pass confirm: true to actually commit. Picks up in-image code changes and any existing .lepiter files that changed on disk.'
]

{ #category : 'accessing' }
MyGtMcpCommitRepositoryTool class >> toolName [
	^ 'commitRepository'
]

{ #category : 'execution' }
MyGtMcpCommitRepositoryTool >> executeWithArguments: arguments [
	| name message confirm repository changedNodes firstLine shortSha noChangesResponse |
	name := (arguments at: 'name') asString.
	message := (arguments at: 'message') asString.
	message trimmed isEmpty ifTrue: [
		MyGtMcpJsonRpcError
			signalCode: -32602
			message: 'Invalid params'
			data: {'reason' -> 'Message must be non-empty'} asDictionary ].
	confirm := arguments at: 'confirm' ifAbsent: [ false ].
	repository := MyGtMcpGitLookup repositoryNamed: name.
	changedNodes := MyGtMcpGitLookup changedNodesForRepository: repository.
	firstLine := (message lines detect: [ :ln | ln trimmed notEmpty ] ifNone: [ message ]) trimmed.
	noChangesResponse := [
		shortSha := repository head commit id first: (8 min: repository head commit id size).
		String streamContents: [ :stream |
			stream nextPutAll: 'No changes to commit.'; lf.
			stream nextPutAll: 'HEAD: '; nextPutAll: shortSha;
				nextPutAll: ' — ';
				nextPutAll: (repository head commit comment lines
					detect: [ :ln | ln trimmed notEmpty ] ifNone: [ '' ]) trimmed ] ].
	confirm = true ifFalse: [
		^ String streamContents: [ :stream |
			stream nextPutAll: 'Dry run — not committed.'; lf.
			stream nextPutAll: 'Repository: '; nextPutAll: repository name;
				nextPutAll: ' (branch: '; nextPutAll: repository branchName; nextPutAll: ')'; lf.
			stream nextPutAll: changedNodes size asString; nextPutAll: ' changes'; lf.
			stream nextPutAll: 'Message: '; nextPutAll: firstLine; lf; lf.
			stream nextPutAll: 'Re-invoke with confirm: true to commit.'; lf.
			stream nextPutAll: 'Or read gtmcp://git/repository/'; nextPutAll: repository name;
				nextPutAll: '/changes for per-file summary.' ] ].
	changedNodes isEmpty ifTrue: [ ^ noChangesResponse value ].
	[ [ repository workingCopy commitWithMessage: message ]
		on: IceNothingToCommit
		do: [ ^ noChangesResponse value ] ]
		on: IceError
		do: [ :anError |
			MyGtMcpJsonRpcError
				signalCode: -32000
				message: 'Commit failed'
				data: {
					'name' -> repository name.
					'branch' -> repository branchName.
					'errorClass' -> anError class name asString.
					'error' -> anError messageText } asDictionary ].
	shortSha := repository head commit id first: (8 min: repository head commit id size).
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Committed '; nextPutAll: shortSha; lf.
		stream nextPutAll: '  '; nextPutAll: firstLine; lf.
		stream nextPutAll: '  '; nextPutAll: changedNodes size asString;
			nextPutAll: ' changes (packages: '; nextPutAll: repository workingCopy packages size asString; nextPutAll: ')' ]
]
