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
ClaudeMcpServer >> addAddSnippetTool [
	self addTool: (GtLlmFunctionTool new
		name: 'addSnippet';
		parameters: {'pageTitle'. 'content'. 'snippetType'};
		description: 'Adds a new snippet to a Lepiter page. snippetType can be "text" or "pharo". Returns the new snippet UID.';
		block: [ :functionCall |
			| db page args content snippetType snippet |
			args := functionCall arguments.
			db := LeDatabasesRegistry default defaultLogicalDatabase.
			page := db pageNamed: (args at: 'pageTitle') ifAbsent: [
				| newPage |
				newPage := LePage named: (args at: 'pageTitle').
				db addPage: newPage.
				newPage ].
			content := args at: 'content'.
			snippetType := args at: 'snippetType' ifAbsent: ['text'].
			snippet := snippetType = 'pharo'
				ifTrue: [LePharoSnippet code: content]
				ifFalse: [LeTextSnippet string: content].
			page addSnippet: snippet.
			'Added snippet: ', snippet uid asString ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addAddTableSnippetTool [
	self addTool: (GtLlmFunctionTool new
		name: 'addTableSnippet';
		parameters: {'pageTitle'. 'columns'. 'rows'. 'height'};
		description: 'Adds an inline table snippet (LeElementSnippet with GtPhlowColumnedListView) to a Lepiter page. columns is a JSON array of objects with "title", "key" (one of "first","second","third",... or "at1","at2",...), and optional "weight" (float, default 1). rows is a JSON array of arrays (each inner array is one row of cell values). height is optional pixel height (default "200"). Returns the new snippet UID.';
		block: [ :functionCall |
			| db page args colDefs rowData height code snippet |
			args := functionCall arguments.
			colDefs := STONJSON fromString: (args at: 'columns').
			rowData := STONJSON fromString: (args at: 'rows').
			height := (args at: 'height' ifAbsent: [ '200' ]) asInteger.

			db := LeDatabasesRegistry default defaultLogicalDatabase.
			page := db pageNamed: (args at: 'pageTitle') ifAbsent: [
				| newPage |
				newPage := LePage named: (args at: 'pageTitle').
				db addPage: newPage.
				newPage ].

			code := self buildTableCode: colDefs rows: rowData.

			snippet := LeElementSnippet new
				code: code;
				codeVisible: false;
				elementHeight: height.
			page addSnippet: snippet.
			'Added table snippet: ' , snippet uid asString ])
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
	self addSchemaToolClass: MyGtMcpAddTableSnippetTool
]

{ #category : 'tools' }
ClaudeMcpServer >> addDefineClassTool [
	self addTool: (GtLlmFunctionTool new
		name: 'defineClass';
		parameters: {'superclassName'. 'className'. 'instanceVariableNames'. 'package'};
		description: 'Defines a new class. superclassName is the parent class (e.g., "Object"), className is the new class name, instanceVariableNames is a space-separated string of ivar names, package is the package name.';
		block: [ :functionCall |
			| args superclassName |
			args := functionCall arguments.
			superclassName := (args at: 'superclassName') asSymbol.
			(Smalltalk globals includesKey: superclassName)
				ifFalse: [ 'Superclass not found: ', superclassName ]
				ifTrue: [
					(Smalltalk globals at: superclassName)
						subclass: (args at: 'className') asSymbol
						instanceVariableNames: (args at: 'instanceVariableNames' ifAbsent: [ '' ])
						classVariableNames: ''
						package: (args at: 'package').
					'Class defined: ', (args at: 'className') ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addDefineMethodTool [
	self addTool: (GtLlmFunctionTool new
		name: 'defineMethod';
		parameters: {'className'. 'sourceCode'. 'protocol'};
		description: 'Defines or updates a method on a class. For class-side methods, append " class" to className (e.g., "MyClass class"). The sourceCode should be the complete method source including the selector.';
		block: [ :functionCall |
			| args className sourceCode protocol theClass isClassSide |
			args := functionCall arguments.
			className := args at: 'className'.
			sourceCode := args at: 'sourceCode'.
			protocol := args at: 'protocol' ifAbsent: [ 'api' ].
			isClassSide := className endsWith: ' class'.
			isClassSide ifTrue: [ className := className allButLast: 6 ].
			(Smalltalk globals includesKey: className asSymbol)
				ifFalse: [ 'Class not found: ', className ]
				ifTrue: [
					theClass := Smalltalk globals at: className asSymbol.
					isClassSide ifTrue: [ theClass := theClass class ].
					theClass compile: sourceCode classified: protocol.
					'Method defined: ', theClass name, '>>#', (sourceCode lines first copyUpTo: Character cr) ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addEvaluateTool [
	self addTool: (GtLlmFunctionTool new
		name: 'evaluate';
		parameters: {'expression'. 'maxLength'. 'includeVisual'. 'imageSize'};
		description: 'Evaluates a Smalltalk expression and returns the result. Results are truncated to maxLength (default 2000 characters). If includeVisual is true, also returns an inline PNG image of the evaluated object. Use imageSize (default 800) to control the maximum image dimension. Also returns available inspector views in the text response.';
		block: [ :functionCall |
			| args result max includeVisual imgSize content textResult viewSummary |
			args := functionCall arguments.
			max := (args at: 'maxLength' ifAbsent: [ maxLength ]) asNumber.
			includeVisual := (args at: 'includeVisual' ifAbsent: [ 'false' ]) asString = 'true'.
			imgSize := (args at: 'imageSize' ifAbsent: [ 800 ]) asNumber.
			[ result := Smalltalk compiler evaluate: (args at: 'expression').
			  textResult := self truncate: result printString to: max.
			  viewSummary := self viewSummaryFor: result.
			  content := OrderedCollection new.
			  content add: {
				  'type' -> 'text'.
				  'text' -> (textResult, String cr, '--- Views ---', String cr, viewSummary)
			  } asDictionary.
			  includeVisual ifTrue: [
				  [ content add: (self exportAsBase64PngContent: result maxImageSize: imgSize) ]
					  on: Error
					  do: [ :e | content add: {
						  'type' -> 'text'.
						  'text' -> ('(Image export failed: ', e messageText, ')')
					  } asDictionary ] ].
			  content asArray ]
				on: Error
				do: [ :e | 'Error: ', e class name, ' - ', e messageText ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addGetExamplesTool [
	self addTool: (GtLlmFunctionTool new
		name: 'getExamples';
		parameters: {'name'. 'type'};
		description: 'Gets gtExample methods. Type can be "class" (examples defined in that class, including inherited) or "package" (all examples in package). Returns method names and first lines of code.';
		block: [ :functionCall |
			| args name type examples |
			args := functionCall arguments.
			name := args at: 'name'.
			type := args at: 'type' ifAbsent: [ 'class' ].
			[ examples := type = 'package'
				ifTrue: [ | pkg |
					pkg := RPackageOrganizer default packageNamed: name asSymbol.
					pkg definedClasses flatCollect: [:cls |
						(cls methods, cls class methods) select: [:m | m hasPragmaNamed: #gtExample ]]]
				ifFalse: [ | cls |
					cls := Smalltalk globals at: name asSymbol.
					((Pragma allNamed: #gtExample from: cls to: Object),
					 (Pragma allNamed: #gtExample from: cls class to: Object class))
						reject: [:p | p method methodClass instanceSide == Object]
						thenCollect: [:p | p method]] ]
				on: Error
				do: [ :e | examples := nil ].
			examples
				ifNil: [ 'Not found: ', name, ' (type: ', type, ')' ]
				ifNotNil: [
					String streamContents: [:s |
						s nextPutAll: 'Examples: '; nextPutAll: examples size asString; cr; cr.
						examples do: [:m |
							s nextPutAll: m methodClass name; nextPutAll: '>>#'; nextPutAll: m selector; cr.
							s nextPutAll: '  '; nextPutAll: (m sourceCode lines first: (3 min: m sourceCode lines size)) asString; cr; cr ]] ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addGetImplementorsTool [
	self addTool: (GtLlmFunctionTool new
		name: 'getImplementors';
		parameters: {'methodName'};
		description: 'Gets a method by name and returns a list of methods that implement it.';
		block: [ :functionCall |
			[ Character cr join:
				(functionCall anyArgument asSymbol gtImplementors result toArray wait
					collect: #name) ]
				on: Error
				do: [ :e | 'Error looking up implementors: ', e messageText ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addGetMethodSourceTool [
	self addTool: (GtLlmFunctionTool new
		name: 'getMethodSource';
		parameters: {'methodReference'};
		description: 'Gets the source code for a method. Takes a method reference in the format "ClassName>>#methodName" for instance methods or "ClassName class>>#methodName" for class methods.';
		block: [ :functionCall |
			| ref parts className selector theClass isClassSide |
			ref := functionCall anyArgument.
			parts := ref splitOn: '>>#'.
			parts size = 2
				ifFalse: [ 'Invalid format. Use ClassName>>#method or ClassName class>>#method' ]
				ifTrue: [
					className := parts first.
					selector := parts second asSymbol.
					isClassSide := className endsWith: ' class'.
					isClassSide ifTrue: [ className := className allButLast: 6 ].
					(Smalltalk globals includesKey: className asSymbol)
						ifFalse: [ 'Class not found: ', className ]
						ifTrue: [
							theClass := Smalltalk globals at: className asSymbol.
							isClassSide ifTrue: [ theClass := theClass class ].
							(theClass includesSelector: selector)
								ifFalse: [ 'Method not found: ', ref ]
								ifTrue: [ (theClass >> selector) sourceCode ] ] ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addGetPackageInfoTool [
	self addTool: (GtLlmFunctionTool new
		name: 'getPackageInfo';
		parameters: {'packageName'};
		description: 'Gets information about a package: its classes and their methods.';
		block: [ :functionCall |
			| pkgName pkg classes output |
			pkgName := functionCall anyArgument asSymbol.
			[ pkg := RPackageOrganizer default packageNamed: pkgName ]
				on: Error
				do: [ :e | pkg := nil ].
			pkg
				ifNil: [ 'Package not found: ', pkgName ]
				ifNotNil: [
					classes := pkg definedClasses sorted: [:a :b | a name < b name].
					String streamContents: [:s |
						s nextPutAll: 'Package: '; nextPutAll: pkg name; cr.
						s nextPutAll: 'Classes: '; nextPutAll: classes size asString; cr; cr.
						classes do: [:cls |
							s nextPutAll: cls name; cr.
							s nextPutAll: '  superclass: '; nextPutAll: cls superclass name; cr.
							s nextPutAll: '  ivars: '; nextPutAll: cls instVarNames printString; cr.
							s nextPutAll: '  methods: '; nextPutAll: cls methods size asString; cr ]] ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addGetReferencesTool [
	self addTool: (GtLlmFunctionTool new
		name: 'getReferences';
		parameters: {'name'. 'type'};
		description: 'Gets references to a name. Type can be "class" (all references to a class) or "selector" (all senders of a selector). Returns a list of method references.';
		block: [ :functionCall |
			| args name type results |
			args := functionCall arguments.
			name := args at: 'name'.
			type := args at: 'type'.
			
			results := [
				type = 'class'
					ifTrue: [
						| classSymbol theClass binding |
						classSymbol := name asSymbol.
						(Smalltalk globals includesKey: classSymbol)
							ifFalse: [ ^ 'Class not found: ', name ].
						theClass := Smalltalk globals at: classSymbol.
						binding := theClass binding.
						SystemNavigation default allReferencesTo: binding ]
					ifFalse: [ type = 'selector'
						ifTrue: [
							SystemNavigation default allSendersOf: name asSymbol ]
						ifFalse: [ ^ 'Invalid type: ', type, '. Must be "class" or "selector".' ] ]
			] on: Error do: [ :e | ^ 'Error finding references: ', e messageText ].
			
			results isEmpty
				ifTrue: [ 'No references found' ]
				ifFalse: [
					Character cr join: (results collect: [ :method |
						method methodClass name, '>>#', method selector ]) ] ])
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

{ #category : 'tools' }
ClaudeMcpServer >> addListPagesTool [
	self addTool: (GtLlmFunctionTool new
		name: 'listPages';
		parameters: #('query');
		description: 'Lists Lepiter pages with their titles and UIDs. The optional query parameter filters pages by case-insensitive substring match on the title. Without a query, lists all pages (may be truncated).';
		block: [ :functionCall |
			| db pages query |
			db := LeDatabasesRegistry default defaultLogicalDatabase.
			query := functionCall arguments at: 'query' ifAbsent: [ nil ].
			pages := db pages sorted: [ :a :b | a title < b title ].
			(query notNil and: [ query isNotEmpty ]) ifTrue: [
				pages := pages select: [ :page |
					page title asLowercase includesSubstring: query asLowercase ] ].
			String streamContents: [ :s |
				s nextPutAll: 'Pages ('; nextPutAll: pages size asString; nextPutAll: ' results)'; cr; cr.
				pages do: [ :page |
					s nextPutAll: page uid asString; nextPutAll: ' | '; nextPutAll: page title; cr ] ] ])
]

{ #category : 'tools - lepiter' }
ClaudeMcpServer >> addReadPageTool [
	self addTool: (GtLlmFunctionTool new
		name: 'readPage';
		parameters: {'pageTitle'};
		description: 'Reads a Lepiter page by title. Returns snippets with their UIDs, types, and content.';
		block: [ :functionCall |
			| db page |
			db := LeDatabasesRegistry default defaultLogicalDatabase.
			page := db pages 
				detect: [ :p | p title = functionCall anyArgument ] 
				ifNone: [ nil ].
			page
				ifNil: [ 'Page not found: ', functionCall anyArgument ]
				ifNotNil: [
					String streamContents: [:s |
						s nextPutAll: 'Page: '; nextPutAll: page title; cr.
						s nextPutAll: 'UID: '; nextPutAll: page uid asString; cr.
						s nextPutAll: 'Snippets: '; nextPutAll: page children size asString; cr; cr.
						page children withIndexDo: [:snippet :idx |
							s nextPutAll: idx asString; nextPutAll: '. '.
							s nextPutAll: '['; nextPutAll: snippet class name; nextPutAll: ']'; cr.
							s nextPutAll: '   UID: '; nextPutAll: snippet uid asString; cr.
							s nextPutAll: '   Content: '; nextPutAll: (snippet isTextualSnippet 
								ifTrue: [snippet string] 
								ifFalse: ['(non-textual snippet)']); cr; cr ]] ] ])
]

{ #category : 'tools' }
ClaudeMcpServer >> addReadSnippetTool [
	self addTool: (GtLlmFunctionTool new
		name: 'readSnippet';
		parameters: {'snippetUid'};
		description: 'Reads a specific Lepiter snippet by UID. Returns full content.';
		block: [ :functionCall |
			| db snippet uid |
			uid := LeUID new uidString: functionCall anyArgument.
			db := LeDatabasesRegistry default defaultLogicalDatabase.
			[ snippet := db snippetWithUID: uid ]
				on: Error
				do: [ :e | snippet := nil ].
			snippet
				ifNil: [ 'Snippet not found for UID: ', functionCall anyArgument ]
				ifNotNil: [
					String streamContents: [:s |
						s nextPutAll: 'Type: '; nextPutAll: snippet class name; cr.
						s nextPutAll: 'UID: '; nextPutAll: snippet uid asString; cr; cr.
						s nextPutAll: 'Content:'; cr.
						s nextPutAll: (snippet isTextualSnippet 
							ifTrue: [snippet string] 
							ifFalse: ['(non-textual snippet)'])] ] ])
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

{ #category : 'tools' }
ClaudeMcpServer >> addUpdateSnippetTool [
	self addTool: (GtLlmFunctionTool new
		name: 'updateSnippet';
		parameters: {'snippetUid'. 'content'};
		description: 'Updates a Lepiter snippet content by UID. Only works for textual snippets.';
		block: [ :functionCall |
			| db snippet uid args content |
			args := functionCall arguments.
			uid := LeUID new uidString: (args at: 'snippetUid').
			content := args at: 'content'.
			db := LeDatabasesRegistry default defaultLogicalDatabase.
			[ snippet := db snippetWithUID: uid ]
				on: Error
				do: [ :e | snippet := nil ].
			snippet
				ifNil: [ 'Snippet not found for UID: ', (args at: 'snippetUid') ]
				ifNotNil: [
					snippet isTextualSnippet
						ifFalse: [ 'Error: Cannot update non-textual snippet (', snippet class name, ')' ]
						ifTrue: [
							snippet updateString: content.
							'Updated snippet: ', snippet uid asString ] ] ])
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
