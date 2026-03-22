Class {
	#name : 'MyGtMcpDefineMethodTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpDefineMethodTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'className' -> {'type' -> 'string'} asDictionary.
			'sourceCode' -> {'type' -> 'string'} asDictionary.
			'protocol' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('className' 'sourceCode').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpDefineMethodTool class >> toolDescription [
	^ 'Defines or updates a method on a class. For class-side methods, append " class" to className (e.g., "MyClass class"). The sourceCode should be the complete method source including the selector.'
]

{ #category : 'accessing' }
MyGtMcpDefineMethodTool class >> toolName [
	^ 'defineMethod'
]

{ #category : 'execution' }
MyGtMcpDefineMethodTool >> executeWithArguments: arguments [
	| className sourceCode protocol theClass isClassSide |
	className := arguments at: 'className'.
	sourceCode := arguments at: 'sourceCode'.
	protocol := arguments at: 'protocol' ifAbsent: [ 'api' ].
	isClassSide := className endsWith: ' class'.
	isClassSide ifTrue: [ className := className allButLast: 6 ].
	(Smalltalk globals includesKey: className asSymbol)
		ifFalse: [ ^ 'Class not found: ', className ].
	theClass := Smalltalk globals at: className asSymbol.
	isClassSide ifTrue: [ theClass := theClass class ].
	theClass compile: sourceCode classified: protocol.
	^ 'Method defined: ', theClass name, '>>#', (sourceCode lines first copyUpTo: Character cr)
]
