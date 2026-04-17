"
An MCP (Model Context Protocol) server that exposes Glamorous Toolkit capabilities as tools for Claude and other LLM clients.

ClaudeMcpServer wraps a GtMcpServer and registers a set of tools that allow an LLM to interact with the GT environment: evaluating Smalltalk code, browsing classes and methods, managing Lepiter knowledge base pages, and more.

## Quick Start

Start a server on a given port:

```
server := ClaudeMcpServer startOnPort: 8200.
```

Or create and configure before starting:

```
server := ClaudeMcpServer new.
server port: 8100.
server maxLength: 5000.
server start.
```

Stop the server when done:

```
server stop.
```

## Configuration

- `port:` — sets the HTTP port the MCP server listens on.
- `maxLength:` — sets the maximum character length for tool result strings (default: 2000).

## Available Tools

The server registers the following tools via `addAllTools`:

**Code browsing**
- `getImplementors` — find implementors of a method name.
- `getMethodSource` — get the source code of a method by reference (e.g. `ClassName>>#method`).
- `getPackageInfo` — list classes and methods in a package.
- `getExamples` — list gtExample methods for a class or package.

**Code editing**
- `defineClass` — define a new class.
- `defineMethod` — define or update a method on a class.
- `evaluate` — evaluate a Smalltalk expression and return the result.

**Lepiter knowledge base**
- `listPages` — list all Lepiter pages.
- `readPage` — read a page by title.
- `readSnippet` — read a snippet by UID.
- `updateSnippet` — update a snippet's content.
- `addSnippet` — add a new snippet to a page.

## Instance Variables

- `server` — the underlying `GtMcpServer` instance.
- `maxLength` — maximum character length for truncating tool output (default 2000).

"
Class {
	#name : 'ClaudeMcpServer',
	#superclass : 'Object',
	#instVars : [
		'server',
		'maxLength',
		'announcer'
	],
	#classInstVars : [
		'DefaultInstance'
	],
	#category : 'Claude-MCP',
	#package : 'Claude-MCP'
}

{ #category : 'actions' }
ClaudeMcpServer class >> cleanupDuplicateInstances [
	| instances running keep |
	instances := self allInstances.
	running := instances select: [ :each | each isRunning ].
	keep := running
		ifNotEmpty: [ running first ]
		ifEmpty: [ instances ifNotEmpty: [ instances first ] ifEmpty: [ nil ] ].
	instances do: [ :each |
		each == keep ifFalse: [
			[ each stop ] on: Error do: [ ].
			[ each releaseResources ] on: Error do: [ ] ] ].
	DefaultInstance := keep.
	Smalltalk garbageCollect.
	^ keep
]

{ #category : 'instance creation' }
ClaudeMcpServer class >> default [
	| running |
	running := self allInstances
		detect: [ :each | each isRunning ]
		ifNone: [ nil ].
	DefaultInstance ifNil: [
		DefaultInstance := running ifNil: [ self new ] ].
	(DefaultInstance isRunning not and: [ running notNil ]) ifTrue: [
		DefaultInstance := running ].
	^ DefaultInstance
]

{ #category : 'actions' }
ClaudeMcpServer class >> reset [
	"Stop and release all live ClaudeMcpServer instances, then clear the default instance."
	self allInstances do: [ :each |
		[ each stop ] on: Error do: [ ].
		[ each releaseResources ] on: Error do: [ ] ].
	DefaultInstance := nil.
	Smalltalk garbageCollect
]

{ #category : 'accessing' }
ClaudeMcpServer class >> resetDefault [
	DefaultInstance ifNotNil: [ :inst | 
		[ inst stop ] on: Error do: [ "ignore" ] ].
	DefaultInstance := nil
]

{ #category : 'instance creation' }
ClaudeMcpServer class >> startOnPort: aPort [
	| instance |
	instance := self allInstances
		detect: [ :each | each port = aPort ]
		ifNone: [ self new ].
	instance
		port: aPort;
		start.
	DefaultInstance := instance.
	^ instance
]

{ #category : 'tools' }
ClaudeMcpServer >> addAllExtensionTools [
	"Register every MyGtMcpTool subclass that opts in via isMcpExtensionTool.
	Called from addAllTools after the built-in tools are registered.
	Lets extension packages add tools without modifying the MyGtMcp or Claude-MCP core."
	MyGtMcpTool allMcpExtensionToolClasses do: [ :toolClass |
		self addSchemaToolClass: toolClass ]
]

{ #category : 'resources' }
ClaudeMcpServer >> addAllResources [
	self addLepiterResources.
	self addGitResources
]

{ #category : 'tools' }
ClaudeMcpServer >> addAllTools [
	self addSchemaToolClass: MyGtMcpGetImplementorsTool.
	self addSchemaToolClass: MyGtMcpGetMethodSourceTool.
	self addSchemaToolClass: MyGtMcpDefineClassTool.
	self addSchemaToolClass: MyGtMcpDefineMethodTool.
	self addSchemaToolClass: MyGtMcpDeleteClassTool.
	self addSchemaToolClass: MyGtMcpEvaluateTool.
	self addSchemaToolClass: MyGtMcpGetPackageInfoTool.
	self addSchemaToolClass: MyGtMcpGetExamplesTool.
	self addSchemaToolClass: MyGtMcpListPagesTool.
	self addSchemaToolClass: MyGtMcpReadPageTool.
	self addSchemaToolClass: MyGtMcpReadSnippetTool.
	self addSchemaToolClass: MyGtMcpUpdateSnippetTool.
	self addSchemaToolClass: MyGtMcpAddSnippetTool.
	self addSchemaToolClass: MyGtMcpGetReferencesTool.
	self addSchemaToolClass: MyGtMcpAddTableSnippetTool.
	self addAllExtensionTools
]

{ #category : 'resources' }
ClaudeMcpServer >> addGitResources [
	self
		addResourceNamed: 'Git repositories'
		uri: 'gtmcp://git/repositories'
		description: 'List the Git repositories currently loaded in the image.'
		mimeType: 'text/plain'
		contents: [ self resourceTextForGitRepositories ].
	self
		addResourceTemplateNamed: 'Git repository'
		uriTemplate: 'gtmcp://git/repository/{name}'
		description: 'Read summary information for one loaded Git repository.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForGitRepositoryNamed: (variables at: 'name') ].
	self
		addResourceTemplateNamed: 'Git repository changes'
		uriTemplate: 'gtmcp://git/repository/{name}/changes'
		description: 'Read a changed-files summary for one loaded Git repository.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForGitRepositoryChangesNamed: (variables at: 'name') ].
	self
		addResourceTemplateNamed: 'Git repository diff'
		uriTemplate: 'gtmcp://git/repository/{name}/diff'
		description: 'Read a unified textual diff for one loaded Git repository.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForGitRepositoryDiffNamed: (variables at: 'name') ]
]

{ #category : 'resources' }
ClaudeMcpServer >> addLepiterResources [
	self
		addResourceNamed: 'Lepiter databases'
		uri: 'gtmcp://lepiter/databases'
		description: 'List the Lepiter databases available in the current logical database.'
		mimeType: 'text/plain'
		contents: [ self resourceTextForLepiterDatabases ].
	self
		addResourceNamed: 'Lepiter pages'
		uri: 'gtmcp://lepiter/pages'
		description: 'List Lepiter pages across the current logical database.'
		mimeType: 'text/plain'
		contents: [ self resourceTextForLepiterPages ].
	self
		addResourceTemplateNamed: 'Lepiter database'
		uriTemplate: 'gtmcp://lepiter/database/{databaseUuid}'
		description: 'Read summary information for a Lepiter database by UUID.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForLepiterDatabaseUuid: (variables at: 'databaseUuid') ].
	self
		addResourceTemplateNamed: 'Lepiter database pages'
		uriTemplate: 'gtmcp://lepiter/database/{databaseUuid}/pages'
		description: 'List pages inside one Lepiter database by UUID.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForLepiterDatabasePagesUuid: (variables at: 'databaseUuid') ].
	self
		addResourceTemplateNamed: 'Lepiter database title'
		uriTemplate: 'gtmcp://lepiter/database/{databaseUuid}/title/{title}'
		description: 'Read a Lepiter page by exact title inside one database.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForLepiterDatabaseUuid: (variables at: 'databaseUuid') title: (variables at: 'title') ].
	self
		addResourceTemplateNamed: 'Lepiter page'
		uriTemplate: 'gtmcp://lepiter/page/{uid}'
		description: 'Read a Lepiter page by page UUID.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForLepiterPageUid: (variables at: 'uid') ].
	self
		addResourceTemplateNamed: 'Lepiter snippet'
		uriTemplate: 'gtmcp://lepiter/snippet/{uid}'
		description: 'Read a Lepiter snippet by snippet UID.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForLepiterSnippetUid: (variables at: 'uid') ].
	self
		addResourceTemplateNamed: 'Lepiter title resolver'
		uriTemplate: 'gtmcp://lepiter/title/{title}'
		description: 'Resolve an exact Lepiter page title to matching page UUIDs across databases.'
		mimeType: 'text/plain'
		contents: [ :variables | self resourceTextForLepiterTitle: (variables at: 'title') ]
]

{ #category : 'resources' }
ClaudeMcpServer >> addResourceNamed: aName uri: aUri description: aDescription mimeType: aMimeType contents: aBlock [
	| resource |
	resource := GtMcpResource new.
	resource name: aName.
	resource title: aName.
	resource uri: aUri.
	resource description: aDescription.
	resource mimeType: aMimeType asZnMimeType.
	resource contentsBlock: aBlock.
	server addResource: resource
]

{ #category : 'resources' }
ClaudeMcpServer >> addResourceTemplateNamed: aName uriTemplate: aUriTemplate description: aDescription mimeType: aMimeType contents: aBlock [
	| template |
	template := MyGtMcpResourceTemplate new.
	template name: aName.
	template title: aName.
	template uriTemplate: aUriTemplate.
	template description: aDescription.
	template mimeType: aMimeType.
	template contentsBlock: aBlock.
	server addResourceTemplate: template
]

{ #category : 'tools' }
ClaudeMcpServer >> addSchemaToolClass: aToolClass [
	server addTool: (aToolClass on: self)
]

{ #category : 'tools' }
ClaudeMcpServer >> addTool: aTool [
	(aTool isKindOf: GtLlmFunctionTool)
		ifTrue: [
			| originalBlock |
			originalBlock := aTool block.
			aTool block: [ :call |
				| result |
				result := originalBlock value: call.
				(result isArray and: [ result allSatisfy: #isDictionary ])
					ifTrue: [ self truncateContentItems: result ]
					ifFalse: [ self truncate: result ] ].
			server addTool: aTool ]
		ifFalse: [ server addTool: aTool ]
]

{ #category : 'accessing' }
ClaudeMcpServer >> announcer [
	^ announcer ifNil: [ announcer := Announcer new ]
]

{ #category : 'private' }
ClaudeMcpServer >> asExportableElement: anObject [
	"Convert anObject to a BlElement for PNG export."
	(anObject isKindOf: BlElement) ifTrue: [ ^ anObject ].
	(anObject isKindOf: Color) ifTrue: [
		^ BlElement new background: anObject; size: 50@50 ].
	^ anObject asElement
]

{ #category : 'private' }
ClaudeMcpServer >> buildTableCode: colDefs rows: rowData [
	"Build the Smalltalk code string for a LeElementSnippet that renders a table.
	colDefs is an array of dictionaries with 'title' and optional 'weight'.
	rowData is an array of arrays (each inner array is one row).
	Since we build the code string programmatically (not as a literal),
	embedded strings use single quotes only. The snippet evaluates this code directly."

	| stream q |
	stream := String new writeStream.
	q := ''''.
	stream
		nextPutAll: '| view |'; cr;
		nextPutAll: 'view := GtPhlowColumnedListView new.'; cr;
		nextPutAll: 'view items: [ {'; cr.

	rowData doWithIndex: [ :row :rowIndex |
		stream nextPutAll: '  { '.
		row doWithIndex: [ :cell :cellIndex |
			| escaped |
			escaped := cell asString copyReplaceAll: q with: q, q.
			stream
				nextPut: $';
				nextPutAll: escaped;
				nextPut: $'.
			cellIndex < row size ifTrue: [ stream nextPutAll: '. ' ] ].
		stream nextPutAll: ' }'.
		rowIndex < rowData size ifTrue: [ stream nextPut: $. ].
		stream cr ].

	stream nextPutAll: '} ].'; cr.

	colDefs doWithIndex: [ :col :index |
		| title weight escaped |
		escaped := (col at: 'title') copyReplaceAll: q with: q, q.
		weight := col at: 'weight' ifAbsent: [ nil ].
		stream
			nextPutAll: 'view column: ';
			nextPut: $';
			nextPutAll: escaped;
			nextPut: $';
			nextPutAll: ' text: [ :row | row at: ';
			nextPutAll: index asString;
			nextPutAll: ' ]'.
		weight ifNotNil: [
			stream nextPutAll: ' weight: '; nextPutAll: weight asString ].
		stream nextPut: $.; cr ].

	stream nextPutAll: 'view asElement'.
	^ stream contents
]

{ #category : 'completion' }
ClaudeMcpServer >> completionValuesForGitRepositoryName: aQuery [
	^ self filteredCompletionValues: (self gitRepositories collect: #name) matching: aQuery
]

{ #category : 'completion' }
ClaudeMcpServer >> completionValuesForLepiterDatabaseTitle: aQuery context: aContext [
	| databaseUuid database titles |
	databaseUuid := self requiredCompletionContextValueNamed: 'databaseUuid' from: aContext.
	database := self lepiterDatabaseByUuidString: databaseUuid.
	titles := database pages collect: #title.
	^ self filteredCompletionValues: titles matching: aQuery
]

{ #category : 'completion' }
ClaudeMcpServer >> completionValuesForLepiterDatabaseUuid: aQuery [
	^ self
		filteredCompletionValues: (self lepiterLogicalDatabase databases collect: #uuidString)
		matching: aQuery
]

{ #category : 'completion' }
ClaudeMcpServer >> completionValuesForLepiterPageUid: aQuery [
	^ self
		filteredCompletionValues: (self lepiterLogicalDatabase pages collect: [ :each | each uid asString ])
		matching: aQuery
]

{ #category : 'completion' }
ClaudeMcpServer >> completionValuesForLepiterSnippetUid: aQuery [
	| values |
	values := OrderedCollection new.
	self lepiterLogicalDatabase snippetsDo: [ :snippet | values add: snippet uid asString ].
	^ self filteredCompletionValues: values matching: aQuery
]

{ #category : 'completion' }
ClaudeMcpServer >> completionValuesForLepiterTitle: aQuery [
	^ self
		filteredCompletionValues: (self lepiterLogicalDatabase pages collect: #title)
		matching: aQuery
]

{ #category : 'completion' }
ClaudeMcpServer >> completionValuesForResourceTemplateUri: aUriTemplate argument: argument context: context [
	| argumentName query |
	argumentName := argument at: 'name'.
	query := argument at: 'value'.
	aUriTemplate = 'gtmcp://lepiter/database/{databaseUuid}' ifTrue: [ ^ self completionValuesForLepiterDatabaseUuid: query ].
	aUriTemplate = 'gtmcp://lepiter/database/{databaseUuid}/pages' ifTrue: [ ^ self completionValuesForLepiterDatabaseUuid: query ].
	aUriTemplate = 'gtmcp://lepiter/database/{databaseUuid}/title/{title}' ifTrue: [
		argumentName = 'databaseUuid' ifTrue: [ ^ self completionValuesForLepiterDatabaseUuid: query ].
		argumentName = 'title' ifTrue: [ ^ self completionValuesForLepiterDatabaseTitle: query context: context ]. ].
	aUriTemplate = 'gtmcp://lepiter/page/{uid}' ifTrue: [ ^ self completionValuesForLepiterPageUid: query ].
	aUriTemplate = 'gtmcp://lepiter/snippet/{uid}' ifTrue: [ ^ self completionValuesForLepiterSnippetUid: query ].
	aUriTemplate = 'gtmcp://lepiter/title/{title}' ifTrue: [ ^ self completionValuesForLepiterTitle: query ].
	(aUriTemplate = 'gtmcp://git/repository/{name}'
		or: [ aUriTemplate = 'gtmcp://git/repository/{name}/changes'
		or: [ aUriTemplate = 'gtmcp://git/repository/{name}/diff' ] ]) ifTrue: [
		^ self completionValuesForGitRepositoryName: query ].
	MyGtMcpJsonRpcError
		signalCode: -32602
		message: 'Invalid params'
		data: {'uriTemplate' -> aUriTemplate. 'argument' -> argumentName} asDictionary
]

{ #category : 'gt-views' }
ClaudeMcpServer >> encodedUriSegment: aString [
	^ ZnPercentEncoder new encode: aString
]

{ #category : 'private' }
ClaudeMcpServer >> ensureServer [
	| currentPort oldServer |
	currentPort := server ifNil: [ self port ] ifNotNil: [ server port ].
	(server notNil and: [ server class ~= MyGtMcpServer ]) ifTrue: [
		oldServer := server.
		[ oldServer stop ] on: Error do: [ ].
		server := nil ].
	server ifNil: [ server := MyGtMcpServer new ].
	server port: currentPort.
	^ server
]

{ #category : 'gt-views' }
ClaudeMcpServer >> exampleUriForTemplate: aTemplate [
	| variables uri |
	variables := self exampleVariablesForTemplate: aTemplate.
	variables ifNil: [ ^ '(no example available)' ].
	uri := aTemplate uriTemplate.
	variables keysAndValuesDo: [ :key :value |
		uri := uri copyReplaceAll: '{', key, '}' with: (self encodedUriSegment: value asString) ].
	^ uri
]

{ #category : 'gt-views' }
ClaudeMcpServer >> exampleVariablesForTemplate: aTemplate [
	| logical database page snippet repository template |
	template := aTemplate uriTemplate.
	logical := self lepiterLogicalDatabase.
	database := logical databases isEmpty ifTrue: [ nil ] ifFalse: [ logical databases anyOne ].
	page := logical pages isEmpty ifTrue: [ nil ] ifFalse: [ logical pages anyOne ].
	snippet := (page isNil or: [ page children size = 0 ]) ifTrue: [ nil ] ifFalse: [ page children first ].
	repository := self gitRepositories isEmpty ifTrue: [ nil ] ifFalse: [ self gitRepositories anyOne ].
	template = 'gtmcp://lepiter/database/{databaseUuid}' ifTrue: [ ^ database ifNil: [ nil ] ifNotNil: [ {'databaseUuid' -> database uuidString} asDictionary ] ].
	template = 'gtmcp://lepiter/database/{databaseUuid}/pages' ifTrue: [ ^ database ifNil: [ nil ] ifNotNil: [ {'databaseUuid' -> database uuidString} asDictionary ] ].
	template = 'gtmcp://lepiter/database/{databaseUuid}/title/{title}' ifTrue: [
		(database isNil or: [ database pages isEmpty ]) ifTrue: [ ^ nil ].
		^ {'databaseUuid' -> database uuidString. 'title' -> database pages anyOne title} asDictionary ].
	template = 'gtmcp://lepiter/page/{uid}' ifTrue: [ ^ page ifNil: [ nil ] ifNotNil: [ {'uid' -> page uid asString} asDictionary ] ].
	template = 'gtmcp://lepiter/snippet/{uid}' ifTrue: [ ^ snippet ifNil: [ nil ] ifNotNil: [ {'uid' -> snippet uid asString} asDictionary ] ].
	template = 'gtmcp://lepiter/title/{title}' ifTrue: [ ^ page ifNil: [ nil ] ifNotNil: [ {'title' -> page title} asDictionary ] ].
	template = 'gtmcp://git/repository/{name}' ifTrue: [ ^ repository ifNil: [ nil ] ifNotNil: [ {'name' -> repository name} asDictionary ] ].
	template = 'gtmcp://git/repository/{name}/changes' ifTrue: [ ^ repository ifNil: [ nil ] ifNotNil: [ {'name' -> repository name} asDictionary ] ].
	template = 'gtmcp://git/repository/{name}/diff' ifTrue: [ ^ repository ifNil: [ nil ] ifNotNil: [ {'name' -> repository name} asDictionary ] ].
	^ nil
]

{ #category : 'private' }
ClaudeMcpServer >> exportAsBase64PngContent: anObject maxImageSize: maxDim [
	"Render anObject as an in-memory PNG and return an MCP image content dictionary."
	| form stream base64 |
	form := (anObject isKindOf: Form)
		ifTrue: [
			| f s |
			f := anObject.
			(f width > maxDim or: [ f height > maxDim ]) ifTrue: [
				s := maxDim / (f width max: f height) asFloat.
				f := f scaledToSize: (f extent * s) rounded ].
			f ]
		ifFalse: [
			| element scaleFactor exporter |
			element := self asExportableElement: anObject.
			element forceLayout.
			scaleFactor := (element width max: element height) > maxDim
				ifTrue: [ maxDim / (element width max: element height) asFloat ]
				ifFalse: [ 1.0 ].
			exporter := BlFormExporter new element: element.
			scaleFactor < 1.0 ifTrue: [ exporter scaled: scaleFactor ].
			exporter export ].
	stream := ByteArray new writeStream.
	PNGReadWriter putForm: form onStream: stream.
	base64 := ZnBase64Encoder new encode: stream contents.
	^ {
		'type' -> 'image'.
		'data' -> base64.
		'mimeType' -> 'image/png'
	} asDictionary
]

{ #category : 'completion' }
ClaudeMcpServer >> filteredCompletionValues: aCollection matching: aQuery [
	| query normalizedCandidates prefixMatches substringMatches ordered |
	query := aQuery ifNil: [ '' ] ifNotNil: [ aQuery asString asLowercase ].
	normalizedCandidates := ((aCollection collect: [ :each | each asString ]) asSet asArray)
		asSortedCollection: [ :a :b | a asLowercase < b asLowercase ].
	query isEmpty ifTrue: [ ^ normalizedCandidates asArray ].
	prefixMatches := OrderedCollection new.
	substringMatches := OrderedCollection new.
	normalizedCandidates do: [ :each |
		| lower |
		lower := each asLowercase.
		(lower beginsWith: query)
			ifTrue: [ prefixMatches add: each ]
			ifFalse: [ (lower includesSubstring: query) ifTrue: [ substringMatches add: each ] ] ].
	ordered := OrderedCollection new.
	ordered addAll: prefixMatches.
	ordered addAll: substringMatches.
	^ ordered asArray
]

{ #category : 'resources-private' }
ClaudeMcpServer >> gitChangedNodesForRepository: aRepository [
	^ aRepository workingCopyDiff tree allChildren
		reject: [ :each | each value class name = 'IceNoModification' ]
]

{ #category : 'resources-private' }
ClaudeMcpServer >> gitPatchTextForNode: aNode [
	| operation path oldText newText patch |
	operation := aNode value.
	path := self gitPathStringForNode: aNode.
	oldText := [ operation rightContents ] on: Error do: [ '' ].
	newText := [ operation leftContents ] on: Error do: [ '' ].
	patch := DiffBuilder buildPatchFrom: oldText to: newText.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'diff --gtmcp a/'; nextPutAll: path; nextPutAll: ' b/'; nextPutAll: path; cr.
		stream nextPutAll: '--- a/'; nextPutAll: path; cr.
		stream nextPutAll: '+++ b/'; nextPutAll: path; cr.
		stream nextPutAll: patch patch ]
]

{ #category : 'resources-private' }
ClaudeMcpServer >> gitPathStringForNode: aNode [
	^ aNode path asString
]

{ #category : 'resources' }
ClaudeMcpServer >> gitRepositories [
	^ IceRepository registry asSortedCollection: [ :a :b | a name < b name ]
]

{ #category : 'resources-private' }
ClaudeMcpServer >> gitRepositoryNamed: aName [
	| repository |
	repository := self gitRepositories detect: [ :each | each name = aName ] ifNone: [ nil ].
	repository ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'repositoryName' -> aName} asDictionary ].
	^ repository
]

{ #category : 'gt-actions' }
ClaudeMcpServer >> gtClearHistoryActionFor: anAction [
	<gtAction>
	^ anAction button
		priority: 5;
		icon: BrGlamorousVectorIcons cancel;
		tooltip: 'Clear history and tool usage stats';
		action: [ :aButton |
			server clearHistory.
			aButton phlow fireToolUpdateWish ]
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtHistoryFor: aView [
	<gtView>
	^ aView forward
		title: 'History';
		priority: 5;
		object: [ server ];
		view: #gtHistoryFor:
]

{ #category : 'gt-actions' }
ClaudeMcpServer >> gtInspectServerActionFor: anAction [
	<gtAction>
	^ anAction button
		priority: 10;
		icon: BrGlamorousVectorIcons inspect;
		tooltip: 'Inspect MCP server';
		action: [ :aButton | aButton phlow spawnObject: server ]
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtLiveLogFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Live log';
		priority: 4;
		items: [ self parsedHistory reversed ];
		column: '#' text: [ :each :idx | idx ] width: 40;
		column: 'Tool' text: [ :each | each at: #toolName ] width: 130;
		column: 'Arguments' text: [ :each |
			| args |
			args := each at: #arguments.
			args isDictionary
				ifTrue: [ 
					(', ' join: (args associations collect: [ :a |
						a key, ': ', (a value asString truncateTo: 40) ])) truncateTo: 120 ]
				ifFalse: [ args asString truncateTo: 120 ] ];
		column: 'Error' text: [ :each |
			(each at: #isError)
				ifTrue: [ 'Yes' ]
				ifFalse: [ '' ] ] width: 50;
		actionUpdateButton
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtOverviewFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Overview';
		priority: 1;
		items: [
			| znServer isRunning |
			znServer := server instVarNamed: 'server'.
			isRunning := znServer notNil and: [ znServer isRunning ].
			{
				'Status' -> (isRunning ifTrue: [ 'Running' ] ifFalse: [ 'Stopped' ]).
				'Port' -> server port.
				'Max length' -> maxLength.
				'Tools' -> server tools size.
				'Debug' -> server isDebug
			} ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtResourcePreviewsFor: aView [
	<gtView>
	(self resourceItems isEmpty and: [ self resourceTemplateItems isEmpty ]) ifTrue: [ ^ aView empty ].
	^ aView columnedList
		title: 'Resource Previews';
		priority: 17;
		items: [ self resourcePreviewRows ];
		column: 'Type' text: [ :each | each at: 'type' ] width: 80;
		column: 'Name' text: [ :each | each at: 'name' ] weight: 0.7;
		column: 'URI' text: [ :each | each at: 'uri' ] weight: 1.4;
		column: 'Preview' text: [ :each | each at: 'preview' ] weight: 2.2
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtResourceTemplatesFor: aView [
	<gtView>
	self resourceTemplateItems ifEmpty: [ ^ aView empty ].
	^ aView columnedList
		title: 'Resource Templates';
		priority: 16;
		items: [ self resourceTemplateItems ];
		column: 'Name' text: [ :each | each name ] weight: 0.7;
		column: 'URI Template' text: [ :each | each uriTemplate ] weight: 1.4;
		column: 'Example URI' text: [ :each | self exampleUriForTemplate: each ] weight: 1.4;
		column: 'Description' text: [ :each | each description ] weight: 1.4
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtResourcesFor: aView [
	<gtView>
	self resourceItems ifEmpty: [ ^ aView empty ].
	^ aView columnedList
		title: 'Resources';
		priority: 15;
		items: [ self resourceItems ];
		column: 'Name' text: [ :each | each name ] weight: 0.7;
		column: 'URI' text: [ :each | each uri ] weight: 1.4;
		column: 'Mime Type' text: [ :each | each mimeType asString ] width: 110;
		column: 'Description' text: [ :each | each description ] weight: 1.4
]

{ #category : 'gt-actions' }
ClaudeMcpServer >> gtStartStopActionFor: anAction [
	<gtAction>
	^ anAction button
		priority: 1;
		icon: BrGlamorousVectorIcons play;
		tooltip: 'Start/Stop server';
		action: [ :aButton :aTab |
			| znServer isRunning |
			znServer := server instVarNamed: 'server'.
			isRunning := znServer notNil and: [ znServer isRunning ].
			isRunning
				ifTrue: [ self stop ]
				ifFalse: [ self start ].
			aButton phlow fireToolUpdateWish ]
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtToolUsageFor: aView [
	<gtView>
	^ aView explicit
		title: 'Tool usage';
		priority: 3;
		stencil: [ | parsed counts toolCounts theData maxCount |
			parsed := self parsedHistory.
			parsed
				ifEmpty: [ BrLabel new
						aptitude: BrGlamorousLabelAptitude new;
						text: 'No history yet' ]
				ifNotEmpty: [ counts := Dictionary new.
					parsed
						do: [ :each | 
							| name |
							name := each at: #toolName.
							counts at: name put: (counts at: name ifAbsent: [ 0 ]) + 1 ].
					toolCounts := counts associations sorted: [ :a :b | a value > b value ].
					theData := GtPlotterDataGroup new values: toolCounts.
					theData := theData labelled: [ :each | each key ].
					theData := theData
							background: [ :each | 
								Color
									r: 66
									g: 188
									b: 238
									range: 255 ].
					maxCount := toolCounts first value.
					GtPlotterHorizontalBarChart new
						barLabelSpacing: 150;
						barWidthScale: (GtPlotterLinearScale new domainFrom: 0 to: maxCount);
						barWidthData: [ :each | each value ];
						amountOfTicks: (maxCount min: 10);
						tickLabelFormat: [ :val | val truncated asString ];
						barElement: [ :aGtPlotterContext | 
							BlElement new
								aptitude: ((BrGlamorousWithExplicitTooltipAptitude
										text: aGtPlotterContext originalValue key , ': '
												, aGtPlotterContext originalValue value asString)
										hideDelay: 0;
										showDelay: 0) ];
						with: theData ] ]
]

{ #category : 'gt-views' }
ClaudeMcpServer >> gtToolsFor: aView [
	<gtView>
	server tools ifEmpty: [ ^ aView empty ].
	^ aView forward
		title: 'Tools';
		priority: 2;
		object: [ server tools ];
		view: #gtItemsFor:
]

{ #category : 'initialization' }
ClaudeMcpServer >> initialize [
	super initialize.
	maxLength := 2000.
	server := GtMcpServer new port: 3030.
]

{ #category : 'testing' }
ClaudeMcpServer >> isRunning [
	^ server notNil
		and: [ (server instVarNamed: #server) notNil
		and: [ (server instVarNamed: #server) isRunning ] ]
]

{ #category : 'resources-private' }
ClaudeMcpServer >> lepiterDatabaseByUuidString: aString [
	| database |
	database := self lepiterLogicalDatabase databases
		detect: [ :each | each uuidString = aString ]
		ifNone: [ nil ].
	database ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'databaseUuid' -> aString} asDictionary ].
	^ database
]

{ #category : 'resources' }
ClaudeMcpServer >> lepiterLogicalDatabase [
	^ LeDatabasesRegistry default defaultLogicalDatabase
]

{ #category : 'resources-private' }
ClaudeMcpServer >> lepiterPageByUidString: aString [
	| uuid page |
	[ uuid := UUID fromString: aString ]
		on: Error
		do: [ MyGtMcpJsonRpcError
				signalCode: -32002
				message: 'Resource not found'
				data: {'pageUid' -> aString} asDictionary ].
	self lepiterLogicalDatabase databases do: [ :database |
		page := [ database pageByUuid: uuid ] on: Error do: [ nil ].
		page ifNotNil: [ ^ page ] ].
	MyGtMcpJsonRpcError
		signalCode: -32002
		message: 'Resource not found'
		data: {'pageUid' -> aString} asDictionary
]

{ #category : 'resources-private' }
ClaudeMcpServer >> lepiterPagesMatchingTitle: aTitle [
	| matches |
	matches := OrderedCollection new.
	self lepiterLogicalDatabase databases do: [ :database |
		| page |
		page := [ database pageNamed: aTitle ] on: Error do: [ nil ].
		page ifNotNil: [ matches add: page ] ].
	^ matches asArray
]

{ #category : 'resources-private' }
ClaudeMcpServer >> lepiterSnippetByUidString: aString [
	| snippet uid |
	uid := LeUID new uidString: aString.
	[ snippet := self lepiterLogicalDatabase snippetWithUID: uid ]
		on: Error
		do: [ snippet := nil ].
	snippet ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'snippetUid' -> aString} asDictionary ].
	^ snippet
]

{ #category : 'accessing' }
ClaudeMcpServer >> maxLength [
	^ maxLength
]

{ #category : 'accessing' }
ClaudeMcpServer >> maxLength: aNumber [
	maxLength := aNumber
]

{ #category : 'private' }
ClaudeMcpServer >> parsedHistory [
	"Parse history into a collection of dictionaries with keys: toolName, arguments, result, isError, request, response"
	| history |
	history := server instVarNamed: 'history'.
	^ history collect: [ :assoc |
		| reqJson respJson params toolName args result isError |
		reqJson := [ NeoJSONReader fromString: assoc key entity contents ] on: Error do: [ :e | Dictionary new ].
		respJson := [ NeoJSONReader fromString: assoc value entity contents ] on: Error do: [ :e | Dictionary new ].
		params := reqJson at: 'params' ifAbsent: [ Dictionary new ].
		toolName := params at: 'name' ifAbsent: [ reqJson at: 'method' ifAbsent: [ '?' ] ].
		args := params at: 'arguments' ifAbsent: [ Dictionary new ].
		result := respJson at: 'result' ifAbsent: [ Dictionary new ].
		isError := (result isDictionary and: [ result at: 'isError' ifAbsent: [ false ] ]).
		{ 
			#toolName -> toolName.
			#arguments -> args.
			#result -> result.
			#isError -> isError.
			#request -> assoc key.
			#response -> assoc value
		} asDictionary ]
]

{ #category : 'accessing' }
ClaudeMcpServer >> port [
	^ server
		ifNil: [ 3030 ]
		ifNotNil: [ server port ]
]

{ #category : 'accessing' }
ClaudeMcpServer >> port: aPort [
	self ensureServer.
	server port: aPort
]

{ #category : 'gt-views' }
ClaudeMcpServer >> previewTextForTemplate: aTemplate [
	| variables |
	variables := self exampleVariablesForTemplate: aTemplate.
	variables ifNil: [ ^ '(no example available)' ].
	^ aTemplate contentsForVariables: variables
]

{ #category : 'lifecycle' }
ClaudeMcpServer >> releaseResources [
	server ifNotNil: [
		[ server tools removeAll ] on: Error do: [ ].
		[ server resources removeAll ] on: Error do: [ ].
		[ server clearResourceTemplates ] on: Error do: [ ].
		[ server clearHistory ] on: Error do: [ ].
		[ server clearErrors ] on: Error do: [ ] ].
	announcer := nil
]

{ #category : 'resources-private' }
ClaudeMcpServer >> renderLepiterPage: aPage [
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Page: '; nextPutAll: aPage title; cr.
		stream nextPutAll: 'UID: '; nextPutAll: aPage uid asString; cr.
		stream nextPutAll: 'Database: '; nextPutAll: aPage database databaseName; cr.
		stream nextPutAll: 'Snippets: '; nextPutAll: aPage children size asString; cr; cr.
		aPage children withIndexDo: [ :snippet :index |
			stream nextPutAll: index asString; nextPutAll: '. ['; nextPutAll: snippet class name; nextPutAll: ']'; cr.
			stream nextPutAll: '   UID: '; nextPutAll: snippet uid asString; cr.
			stream nextPutAll: '   Content: '; nextPutAll: (snippet isTextualSnippet ifTrue: [ snippet string ] ifFalse: [ '(non-textual snippet)' ]); cr; cr ] ]
]

{ #category : 'resources-private' }
ClaudeMcpServer >> renderLepiterSnippet: aSnippet [
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Type: '; nextPutAll: aSnippet class name; cr.
		stream nextPutAll: 'UID: '; nextPutAll: aSnippet uid asString; cr; cr.
		stream nextPutAll: 'Content:'; cr.
		stream nextPutAll: (aSnippet isTextualSnippet ifTrue: [ aSnippet string ] ifFalse: [ '(non-textual snippet)' ]) ]
]

{ #category : 'completion' }
ClaudeMcpServer >> requiredCompletionContextValueNamed: aName from: aDictionary [
	| value |
	value := aDictionary at: aName ifAbsent: [
		MyGtMcpJsonRpcError
			signalCode: -32602
			message: 'Invalid params'
			data: {'reason' -> 'Missing required context argument'. 'name' -> aName} asDictionary ].
	^ value asString
]

{ #category : 'lifecycle' }
ClaudeMcpServer >> reset [
	| currentPort oldServer |
	currentPort := self port.
	oldServer := server.
	[ self stop ] on: Error do: [ ].
	oldServer ifNotNil: [
		[ oldServer tools removeAll ] on: Error do: [ ].
		[ oldServer resources removeAll ] on: Error do: [ ].
		[ oldServer clearResourceTemplates ] on: Error do: [ ].
		[ oldServer clearHistory ] on: Error do: [ ].
		[ oldServer clearErrors ] on: Error do: [ ].
		[ oldServer stop ] on: Error do: [ ] ].
	server := nil.
	announcer := nil.
	maxLength ifNil: [ maxLength := 2000 ].
	self ensureServer.
	server port: currentPort.
	self addAllTools.
	self addAllResources.
	^ self
]

{ #category : 'gt-views' }
ClaudeMcpServer >> resourceItems [
	^ server ifNil: [ #() ] ifNotNil: [ (server instVarNamed: 'resources') items ]
]

{ #category : 'gt-views' }
ClaudeMcpServer >> resourcePreviewRows [
	| rows |
	rows := OrderedCollection new.
	self resourceItems do: [ :each |
		rows add: {
			'type' -> 'resource'.
			'name' -> each name.
			'uri' -> each uri.
			'preview' -> (self truncatedPreviewText: [ each contents ]) } asDictionary ].
	self resourceTemplateItems do: [ :each |
		| exampleUri |
		exampleUri := self exampleUriForTemplate: each.
		rows add: {
			'type' -> 'template'.
			'name' -> each name.
			'uri' -> exampleUri.
			'preview' -> (self truncatedPreviewText: [ self previewTextForTemplate: each ]) } asDictionary ].
	^ rows
]

{ #category : 'gt-views' }
ClaudeMcpServer >> resourceTemplateItems [
	^ server ifNil: [ #() ] ifNotNil: [ server resourceTemplates ]
]

{ #category : 'resources-git' }
ClaudeMcpServer >> resourceTextForGitRepositories [
	| repositories |
	repositories := self gitRepositories.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Repositories: '; nextPutAll: repositories size asString; cr; cr.
		repositories do: [ :repository |
			stream
				nextPutAll: repository name;
				nextPutAll: ' | ';
				nextPutAll: repository branchName;
				nextPutAll: ' | ';
				nextPutAll: repository location pathString;
				cr ] ]
]

{ #category : 'resources-git' }
ClaudeMcpServer >> resourceTextForGitRepositoryChangesNamed: aName [
	| repository changedNodes |
	repository := self gitRepositoryNamed: aName.
	changedNodes := self gitChangedNodesForRepository: repository.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Changes for '; nextPutAll: repository name; cr; cr.
		changedNodes isEmpty
			ifTrue: [ stream nextPutAll: '(no changes)' ]
			ifFalse: [ changedNodes do: [ :node |
				stream
					nextPutAll: (self gitPathStringForNode: node);
					nextPutAll: ' | ';
					nextPutAll: node value class name;
					cr ] ] ]
]

{ #category : 'resources-git' }
ClaudeMcpServer >> resourceTextForGitRepositoryDiffNamed: aName [
	| repository changedNodes |
	repository := self gitRepositoryNamed: aName.
	changedNodes := self gitChangedNodesForRepository: repository.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Diff for '; nextPutAll: repository name; cr; cr.
		changedNodes isEmpty
			ifTrue: [ stream nextPutAll: '(no changes)' ]
			ifFalse: [ changedNodes do: [ :node |
				stream nextPutAll: (self gitPatchTextForNode: node); cr; cr ] ] ]
]

{ #category : 'resources-git' }
ClaudeMcpServer >> resourceTextForGitRepositoryNamed: aName [
	| repository changedNodes |
	repository := self gitRepositoryNamed: aName.
	changedNodes := self gitChangedNodesForRepository: repository.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Repository: '; nextPutAll: repository name; cr.
		stream nextPutAll: 'Branch: '; nextPutAll: repository branchName; cr.
		stream nextPutAll: 'Head: '; nextPutAll: repository headDescription; cr.
		stream nextPutAll: 'Path: '; nextPutAll: repository location pathString; cr.
		stream nextPutAll: 'Changed nodes: '; nextPutAll: changedNodes size asString ]
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterDatabasePagesUuid: aString [
	| database pages |
	database := self lepiterDatabaseByUuidString: aString.
	pages := database pages asSortedCollection: [ :a :b | a title < b title ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Pages in database: '; nextPutAll: database databaseName; cr.
		stream nextPutAll: 'Database UUID: '; nextPutAll: database uuidString; cr.
		stream nextPutAll: 'Pages: '; nextPutAll: pages size asString; cr; cr.
		pages do: [ :page |
			stream nextPutAll: page uid asString; nextPutAll: ' | '; nextPutAll: page title; cr ] ]
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterDatabaseUuid: aString [
	| database |
	database := self lepiterDatabaseByUuidString: aString.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Database: '; nextPutAll: database databaseName; cr.
		stream nextPutAll: 'UUID: '; nextPutAll: database uuidString; cr.
		stream nextPutAll: 'Pages: '; nextPutAll: database pages size asString ]
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterDatabaseUuid: aString title: aTitle [
	| database page |
	database := self lepiterDatabaseByUuidString: aString.
	page := [ database pageNamed: aTitle ] on: Error do: [ nil ].
	page ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'databaseUuid' -> aString. 'title' -> aTitle} asDictionary ].
	^ self renderLepiterPage: page
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterDatabases [
	| databases |
	databases := self lepiterLogicalDatabase databases asSortedCollection: [ :a :b | a databaseName < b databaseName ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Lepiter databases: '; nextPutAll: databases size asString; cr; cr.
		databases do: [ :database |
			stream
				nextPutAll: database uuidString;
				nextPutAll: ' | ';
				nextPutAll: database databaseName;
				nextPutAll: ' | pages: ';
				nextPutAll: database pages size asString;
				cr ] ]
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterPageUid: aString [
	^ self renderLepiterPage: (self lepiterPageByUidString: aString)
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterPages [
	| pages |
	pages := self lepiterLogicalDatabase pages asSortedCollection: [ :a :b | a title < b title ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Pages: '; nextPutAll: pages size asString; cr; cr.
		pages do: [ :page |
			stream
				nextPutAll: page uid asString;
				nextPutAll: ' | ';
				nextPutAll: page title;
				nextPutAll: ' | ';
				nextPutAll: page database databaseName;
				cr ] ]
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterSnippetUid: aString [
	^ self renderLepiterSnippet: (self lepiterSnippetByUidString: aString)
]

{ #category : 'resources-lepiter' }
ClaudeMcpServer >> resourceTextForLepiterTitle: aTitle [
	| matches |
	matches := self lepiterPagesMatchingTitle: aTitle.
	matches ifEmpty: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'title' -> aTitle} asDictionary ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Title matches for: '; nextPutAll: aTitle; cr; cr.
		matches do: [ :page |
			stream
				nextPutAll: page uid asString;
				nextPutAll: ' | ';
				nextPutAll: page title;
				nextPutAll: ' | ';
				nextPutAll: page database databaseName;
				cr ] ]
]

{ #category : 'accessing' }
ClaudeMcpServer >> server [
	^ server
]

{ #category : 'running' }
ClaudeMcpServer >> start [
	self ensureServer.
	server tools removeAll.
	server resources removeAll.
	(server respondsTo: #clearResourceTemplates)
		ifTrue: [ server clearResourceTemplates ].
	self addAllTools.
	self addAllResources.
	server start.
	self announcer announce: ClaudeMcpServerStarted new.
	^ self
]

{ #category : 'actions' }
ClaudeMcpServer >> stop [
	server ifNotNil: [
		server stop ].
	self announcer announce: ClaudeMcpServerStopped new
]

{ #category : 'utilities' }
ClaudeMcpServer >> truncate: aString [
	^ self truncate: aString to: maxLength
]

{ #category : 'utilities' }
ClaudeMcpServer >> truncate: aString to: max [
	^ aString size > max
		ifTrue: [ (aString first: max), '... (truncated, ', (aString size - max) asString, ' more chars)' ]
		ifFalse: [ aString ]
]

{ #category : 'utilities' }
ClaudeMcpServer >> truncateContentItems: contentArray [
	"Truncate text content items, leave image items untouched."
	^ contentArray collect: [ :item |
		(item at: 'type') = 'text'
			ifTrue: [
				item at: 'text' put: (self truncate: (item at: 'text')).
				item ]
			ifFalse: [ item ] ]
]

{ #category : 'gt-views' }
ClaudeMcpServer >> truncatedPreviewText: aBlock [
	| text |
	text := [ aBlock value ] on: Error do: [ :error | 'Error: ', error messageText ].
	text := text asString.
	^ text size > 180
		ifTrue: [ (text copyFrom: 1 to: 180), '...' ]
		ifFalse: [ text ]
]

{ #category : 'private' }
ClaudeMcpServer >> viewSummaryFor: anObject [
	"I return a one-line summary of available views: 'Print (text), Integer (columned list), Meta'."
	| views |
	views := self viewsFor: anObject.
	^ ', ' join: (views collect: [ :v |
		| hint |
		hint := self viewTypeHintFor: v.
		hint isEmpty
			ifTrue: [ v title ]
			ifFalse: [ v title , ' (' , hint , ')' ] ])
]

{ #category : 'private' }
ClaudeMcpServer >> viewTypeHintFor: aView [
	"I return a short type hint string for the view, or empty if no specific hint applies."
	| map |
	map := {
		GtPhlowTextEditorView -> 'text'.
		GtPhlowTextView -> 'text'.
		GtPhlowColumnedListView -> 'columned list'.
		GtPhlowColumnedTreeView -> 'columned tree'.
		GtPhlowListView -> 'list'.
		GtPhlowTreeView -> 'tree'.
		GtPhlowMondrianView -> 'mondrian'.
		GtPhlowTableView -> 'table'.
		GtPhlowDiffView -> 'diff'.
	} asDictionary.
	^ map at: aView class ifAbsent: [ '' ]
]

{ #category : 'private' }
ClaudeMcpServer >> viewsFor: anObject [
	"I return the non-empty Phlow views for anObject."
	^ (anObject gtViewsInContext: GtPhlowContext new)
		reject: [ :v | v class = GtPhlowEmptyView ]
]
