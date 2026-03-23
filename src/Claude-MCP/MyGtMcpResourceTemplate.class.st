Class {
	#name : 'MyGtMcpResourceTemplate',
	#superclass : 'Object',
	#instVars : [
		'name',
		'title',
		'uriTemplate',
		'mimeType',
		'description',
		'icons',
		'annotations',
		'contentsBlock'
	],
	#category : 'Claude-MCP',
	#package : 'Claude-MCP'
}

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> annotations [
	^ annotations
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> annotations: aDictionary [
	annotations := aDictionary
]

{ #category : 'mcp' }
MyGtMcpResourceTemplate >> asMcpDictionary [
	| dictionary |
	dictionary := {
		'uriTemplate' -> self uriTemplate.
		'name' -> self name.
		'title' -> self title.
		'description' -> self description.
		'mimeType' -> self mimeType asString } asDictionary.
	self icons ifNotNil: [ dictionary at: 'icons' put: self icons ].
	self annotations ifNotNil: [ dictionary at: 'annotations' put: self annotations ].
	^ dictionary
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> contentsBlock [
	^ contentsBlock
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> contentsBlock: aBlock [
	contentsBlock := aBlock
]

{ #category : 'mcp' }
MyGtMcpResourceTemplate >> contentsForVariables: aDictionary [
	^ contentsBlock value: aDictionary
]

{ #category : 'matching' }
MyGtMcpResourceTemplate >> decodedSegment: aString [
	^ ZnPercentEncoder new decode: aString
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> description [
	^ description ifNil: [ '' ]
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> description: aString [
	description := aString
]

{ #category : 'gt-views' }
MyGtMcpResourceTemplate >> gtExampleUriFor: aView [
	<gtView>
	^ aView textEditor
		title: 'Example URI';
		priority: 5;
		text: [ ClaudeMcpServer default exampleUriForTemplate: self ]
]

{ #category : 'gt-views' }
MyGtMcpResourceTemplate >> gtPreviewFor: aView [
	<gtView>
	^ aView textEditor
		title: 'Preview';
		priority: 6;
		text: [ ClaudeMcpServer default previewTextForTemplate: self ]
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> icons [
	^ icons
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> icons: aCollection [
	icons := aCollection
]

{ #category : 'matching' }
MyGtMcpResourceTemplate >> isTemplateVariable: aString [
	^ aString size > 2
		and: [ aString first = ${
		and: [ aString last = $} ] ]
]

{ #category : 'matching' }
MyGtMcpResourceTemplate >> matchesUri: aUri [
	| templateSegments uriSegments variables |
	templateSegments := self uriSegmentsFor: self uriTemplate.
	uriSegments := self uriSegmentsFor: aUri.
	templateSegments size = uriSegments size ifFalse: [ ^ nil ].
	variables := Dictionary new.
	1 to: templateSegments size do: [ :index |
		| templateSegment uriSegment variableName |
		templateSegment := templateSegments at: index.
		uriSegment := uriSegments at: index.
		(self isTemplateVariable: templateSegment)
			ifTrue: [
				variableName := self variableNameFromSegment: templateSegment.
				variables at: variableName put: (self decodedSegment: uriSegment) ]
			ifFalse: [ templateSegment = uriSegment ifFalse: [ ^ nil ] ] ].
	^ variables
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> mimeType [
	^ mimeType ifNil: [ 'text/plain' ]
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> mimeType: aString [
	mimeType := aString
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> name [
	^ name
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> name: aString [
	name := aString
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> title [
	^ title ifNil: [ self name ]
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> title: aString [
	title := aString
]

{ #category : 'matching' }
MyGtMcpResourceTemplate >> uriSegmentsFor: aString [
	^ (aString findTokens: '/') reject: [ :each | each isEmpty ]
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> uriTemplate [
	^ uriTemplate
]

{ #category : 'accessing' }
MyGtMcpResourceTemplate >> uriTemplate: aString [
	uriTemplate := aString
]

{ #category : 'matching' }
MyGtMcpResourceTemplate >> variableNameFromSegment: aString [
	^ aString copyFrom: 2 to: aString size - 1
]
