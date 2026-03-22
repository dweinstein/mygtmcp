Class {
	#name : 'MyGtMcpAddTableSnippetTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpAddTableSnippetTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'pageTitle' -> {
				'type' -> 'string'.
				'description' -> 'Lepiter page title'
			} asDictionary.
			'columns' -> {
				'type' -> 'string'.
				'description' -> 'JSON array of column definitions'
			} asDictionary.
			'rows' -> {
				'type' -> 'string'.
				'description' -> 'JSON array of row arrays'
			} asDictionary.
			'height' -> {
				'type' -> 'integer'.
				'description' -> 'Optional element height'
			} asDictionary
		} asDictionary.
		'required' -> #('pageTitle' 'columns' 'rows').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpAddTableSnippetTool class >> toolDescription [
	^ 'Adds an inline table snippet (LeElementSnippet with GtPhlowColumnedListView) to a Lepiter page. columns is a JSON array of objects with "title", "key" (one of "first","second","third",... or "at1","at2",...), and optional "weight" (float, default 1). rows is a JSON array of arrays (each inner array is one row of cell values). height is optional pixel height (default "200"). Returns the new snippet UID.'
]

{ #category : 'accessing' }
MyGtMcpAddTableSnippetTool class >> toolName [
	^ 'addTableSnippet'
]

{ #category : 'private' }
MyGtMcpAddTableSnippetTool >> buildTableCode: colDefs rows: rowData [
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
			stream nextPutAll: ' weight: ';
				nextPutAll: weight asString ].
		stream nextPut: $.; cr ].
	stream nextPutAll: 'view asElement'.
	^ stream contents
]

{ #category : 'execution' }
MyGtMcpAddTableSnippetTool >> executeWithArguments: arguments [
	| db page colDefs rowData height code snippet |
	colDefs := STONJSON fromString: (arguments at: 'columns').
	rowData := STONJSON fromString: (arguments at: 'rows').
	height := (arguments at: 'height' ifAbsent: [ 200 ]) asInteger.
	db := LeDatabasesRegistry default defaultLogicalDatabase.
	page := db pageNamed: (arguments at: 'pageTitle') ifAbsent: [
		| newPage |
		newPage := LePage named: (arguments at: 'pageTitle').
		db addPage: newPage.
		newPage ].
	code := self buildTableCode: colDefs rows: rowData.
	snippet := LeElementSnippet new
		code: code;
		codeVisible: false;
		elementHeight: height.
	page addSnippet: snippet.
	^ 'Added table snippet: ', snippet uid asString
]
