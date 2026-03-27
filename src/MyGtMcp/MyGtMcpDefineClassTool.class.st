Class {
	#name : 'MyGtMcpDefineClassTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'api' }
MyGtMcpDefineClassTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'superclassName' -> {'type' -> 'string'} asDictionary.
			'className' -> {'type' -> 'string'} asDictionary.
			'instanceVariableNames' -> {'type' -> 'string'} asDictionary.
			'package' -> {'type' -> 'string'} asDictionary.
			'traits' -> {
				'type' -> 'array'.
				'items' -> {'type' -> 'string'} asDictionary.
				'description' -> 'Optional list of trait names (e.g., ["TGtGroupWithItems"])'
			} asDictionary
		} asDictionary.
		'required' -> #('superclassName' 'className' 'package').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'api' }
MyGtMcpDefineClassTool class >> toolDescription [
	^ 'Defines a new class. superclassName is the parent class (e.g., "Object"), className is the new class name, instanceVariableNames is a space-separated string of ivar names, package is the package name. Optionally pass traits as an array of trait names (e.g., ["TGtGroupWithItems"]).'
]

{ #category : 'accessing' }
MyGtMcpDefineClassTool class >> toolName [
	^ 'defineClass'
]

{ #category : 'api' }
MyGtMcpDefineClassTool >> applyTraitsTo: aClass from: arguments [
	| traitNames composition |
	traitNames := arguments at: 'traits' ifAbsent: [ #() ].
	traitNames ifEmpty: [ ^ self ].
	composition := (traitNames collect: [ :each | self resolveTraitNamed: each ])
		reduce: [ :a :b | a + b ].
	aClass setTraitComposition: composition
]

{ #category : 'api' }
MyGtMcpDefineClassTool >> createClassFrom: arguments [
	| superclassName |
	superclassName := (arguments at: 'superclassName') asSymbol.
	(Smalltalk globals includesKey: superclassName)
		ifFalse: [ self error: 'Superclass not found: ' , superclassName ].
	^ (Smalltalk globals at: superclassName)
		subclass: (arguments at: 'className') asSymbol
		instanceVariableNames: (arguments at: 'instanceVariableNames' ifAbsent: [ '' ])
		classVariableNames: ''
		package: (arguments at: 'package')
]

{ #category : 'api' }
MyGtMcpDefineClassTool >> executeWithArguments: arguments [
	| className classExisted newClass |
	className := arguments at: 'className'.
	classExisted := Smalltalk globals includesKey: className asSymbol.
	[ newClass := self createClassFrom: arguments.
	self applyTraitsTo: newClass from: arguments ]
		on: Error
		do: [ :anError |
			classExisted ifFalse: [ Smalltalk globals removeClassNamed: className asSymbol ].
			^ anError messageText ].
	^ 'Class defined: ' , className
]

{ #category : 'api' }
MyGtMcpDefineClassTool >> resolveTraitNamed: aString [
	| trait |
	trait := Smalltalk globals
		at: aString asSymbol
		ifAbsent: [ self error: 'Trait not found: ' , aString ].
	trait isTrait
		ifFalse: [ self error: 'Not a trait: ' , aString ].
	^ trait asTraitComposition
]
