Class {
	#name : 'MyGtMcpDefineClassTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpDefineClassTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'superclassName' -> {'type' -> 'string'} asDictionary.
			'className' -> {'type' -> 'string'} asDictionary.
			'instanceVariableNames' -> {'type' -> 'string'} asDictionary.
			'package' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('superclassName' 'className' 'package').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpDefineClassTool class >> toolDescription [
	^ 'Defines a new class. superclassName is the parent class (e.g., "Object"), className is the new class name, instanceVariableNames is a space-separated string of ivar names, package is the package name.'
]

{ #category : 'accessing' }
MyGtMcpDefineClassTool class >> toolName [
	^ 'defineClass'
]

{ #category : 'execution' }
MyGtMcpDefineClassTool >> executeWithArguments: arguments [
	| superclassName |
	superclassName := (arguments at: 'superclassName') asSymbol.
	(Smalltalk globals includesKey: superclassName)
		ifFalse: [ ^ 'Superclass not found: ', superclassName ].
	(Smalltalk globals at: superclassName)
		subclass: (arguments at: 'className') asSymbol
		instanceVariableNames: (arguments at: 'instanceVariableNames' ifAbsent: [ '' ])
		classVariableNames: ''
		package: (arguments at: 'package').
	^ 'Class defined: ', (arguments at: 'className')
]
