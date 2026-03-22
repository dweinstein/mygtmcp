Class {
	#name : 'MyGtMcpGetMethodSourceTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpGetMethodSourceTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'methodReference' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('methodReference').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpGetMethodSourceTool class >> toolDescription [
	^ 'Gets the source code for a method. Takes a method reference in the format "ClassName>>#methodName" for instance methods or "ClassName class>>#methodName" for class methods.'
]

{ #category : 'accessing' }
MyGtMcpGetMethodSourceTool class >> toolName [
	^ 'getMethodSource'
]

{ #category : 'execution' }
MyGtMcpGetMethodSourceTool >> executeWithArguments: arguments [
	| ref parts className selector theClass isClassSide |
	ref := arguments at: 'methodReference'.
	parts := ref splitOn: '>>#'.
	parts size = 2 ifFalse: [ ^ 'Invalid format. Use ClassName>>#method or ClassName class>>#method' ].
	className := parts first.
	selector := parts second asSymbol.
	isClassSide := className endsWith: ' class'.
	isClassSide ifTrue: [ className := className allButLast: 6 ].
	(Smalltalk globals includesKey: className asSymbol) ifFalse: [ ^ 'Class not found: ', className ].
	theClass := Smalltalk globals at: className asSymbol.
	isClassSide ifTrue: [ theClass := theClass class ].
	(theClass includesSelector: selector) ifFalse: [ ^ 'Method not found: ', ref ].
	^ (theClass >> selector) sourceCode
]
