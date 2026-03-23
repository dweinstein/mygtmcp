Class {
	#name : 'MyGtMcpEvaluateTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpEvaluateTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'expression' -> {
				'type' -> 'string'.
				'description' -> 'Smalltalk expression to evaluate'
			} asDictionary.
			'maxLength' -> {
				'type' -> 'integer'.
				'description' -> 'Maximum text length'
			} asDictionary.
			'includeVisual' -> {
				'type' -> 'boolean'.
				'description' -> 'When true, include an inline PNG image. When omitted, obviously visual results may be auto-rendered.'
			} asDictionary.
			'imageSize' -> {
				'type' -> 'integer'.
				'description' -> 'Maximum image dimension in pixels'
			} asDictionary
		} asDictionary.
		'required' -> #('expression').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpEvaluateTool class >> toolDescription [
	^ 'Evaluates a Smalltalk expression and returns the result. Results are truncated to maxLength (default 2000 characters). If includeVisual is true, also returns an inline PNG image of the evaluated object. Use imageSize (default 800) to control the maximum image dimension. Also returns available inspector views in the text response.'
]

{ #category : 'accessing' }
MyGtMcpEvaluateTool class >> toolName [
	^ 'evaluate'
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> asExportableElement: anObject [
	(anObject isKindOf: BlElement) ifTrue: [ ^ anObject ].
	(anObject isKindOf: Color) ifTrue: [
		^ BlElement new
			background: anObject;
			size: 50@50 ].
	^ anObject asElement
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> booleanValueOf: anObject default: aBoolean [
	anObject ifNil: [ ^ aBoolean ].
	anObject isBoolean ifTrue: [ ^ anObject ].
	^ anObject asString asLowercase = 'true'
]

{ #category : 'execution' }
MyGtMcpEvaluateTool >> executeWithArguments: arguments [
	| result max includeVisual imgSize content textResult viewSummary includeVisualRequested |
	max := (arguments at: 'maxLength' ifAbsent: [ self mcpServer maxLength ]) asNumber.
	includeVisualRequested := arguments includesKey: 'includeVisual'.
	imgSize := (arguments at: 'imageSize' ifAbsent: [ 800 ]) asNumber.
	^ [ result := Smalltalk compiler evaluate: (arguments at: 'expression').
		includeVisual := includeVisualRequested
			ifTrue: [
				self
					booleanValueOf: (arguments at: 'includeVisual')
					default: false ]
			ifFalse: [ self shouldAutoIncludeVisualFor: result ].
		textResult := self mcpServer truncate: result printString to: max.
		viewSummary := self viewSummaryFor: result.
		content := OrderedCollection new.
		content add: (self textContent: textResult).
		content add: (self textContent: 'Views: ', viewSummary).
		includeVisual ifTrue: [
			[ content add: (self exportAsBase64PngContent: result maxImageSize: imgSize) ]
				on: Error
				do: [ :e | content add: (self textContent: '(Image export failed: ', e messageText, ')') ] ].
		content asArray ]
		on: Error
		do: [ :e | 'Error: ', e class name, ' - ', e messageText ]
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> exportAsBase64PngContent: anObject maxImageSize: maxDim [
	| form stream base64 |
	form := (anObject isKindOf: Form)
		ifTrue: [
			| scaledForm scale |
			scaledForm := anObject.
			(scaledForm width > maxDim or: [ scaledForm height > maxDim ]) ifTrue: [
				scale := maxDim / (scaledForm width max: scaledForm height) asFloat.
				scaledForm := scaledForm scaledToSize: (scaledForm extent * scale) rounded ].
			scaledForm ]
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

{ #category : 'private' }
MyGtMcpEvaluateTool >> is: anObject kindOfClassNamed: aSymbol [
	| cls |
	cls := Smalltalk globals at: aSymbol ifAbsent: [ ^ false ].
	^ anObject isKindOf: cls
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> shouldAutoIncludeVisualFor: anObject [
	^ ({ BlElement. Color. Form } anySatisfy: [ :each | anObject isKindOf: each ])
		or: [ ({
			#GtMondrian.
			#GtPlotterBuilder.
			#GtPhlowMondrianView.
			#GtPhlowColumnedListView.
			#GtPhlowColumnedTreeView.
			#GtPhlowListView.
			#GtPhlowTreeView.
			#GtPhlowTableView.
			#GtPhlowDiffView }
				anySatisfy: [ :each | self is: anObject kindOfClassNamed: each ]) ]
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> viewSelectorSuffixFor: aView [
	| selector |
	(aView respondsTo: #definingSelector) ifFalse: [ ^ '' ].
	selector := [ aView definingSelector ] on: Error do: [ ^ '' ].
	selector ifNil: [ ^ '' ].
	^ ' [#', selector asString, ']'
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> viewSummaryFor: anObject [
	| views |
	views := self viewsFor: anObject.
	^ ', ' join: (views collect: [ :view |
		| hint base |
		hint := self viewTypeHintFor: view.
		base := hint isEmpty
			ifTrue: [ view title ]
			ifFalse: [ view title, ' (', hint, ')' ].
		base, (self viewSelectorSuffixFor: view) ])
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> viewTypeHintFor: aView [
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
		GtPhlowDiffView -> 'diff'
	} asDictionary.
	^ map at: aView class ifAbsent: [ '' ]
]

{ #category : 'private' }
MyGtMcpEvaluateTool >> viewsFor: anObject [
	^ (anObject gtViewsInContext: GtPhlowContext new)
		reject: [ :each | each class = GtPhlowEmptyView ]
]
