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

{ #category : 'executing' }
MyGtMcpDefineClassTool >> executeWithArguments: arguments [
	| superclassName className newClass traitNames composition |
	superclassName := (arguments at: 'superclassName') asSymbol.
	(Smalltalk globals includesKey: superclassName)
		ifFalse: [ ^ 'Superclass not found: ', superclassName ].
	className := (arguments at: 'className').
	newClass := (Smalltalk globals at: superclassName)
		subclass: className asSymbol
		instanceVariableNames: (arguments at: 'instanceVariableNames' ifAbsent: [ '' ])
		classVariableNames: ''
		package: (arguments at: 'package').
	traitNames := arguments at: 'traits' ifAbsent: [ #() ].
	traitNames ifEmpty: [ ^ 'Class defined: ', className ].
	composition := traitNames
		inject: nil
		into: [ :currentComposition :eachTraitName |
			| trait |
			trait := Smalltalk globals
				at: eachTraitName asSymbol
				ifAbsent: [
					Smalltalk globals removeClassNamed: className asSymbol.
					^ 'Trait not found: ', eachTraitName asString ].
			(trait isTrait not)
				ifTrue: [
					Smalltalk globals removeClassNamed: className asSymbol.
					^ 'Not a trait: ', eachTraitName asString ].
			currentComposition
				ifNil: [ trait asTraitComposition ]
				ifNotNil: [ currentComposition + trait asTraitComposition ] ].
	[ newClass setTraitComposition: composition ]
		on: Error
		do: [ :anError |
			Smalltalk globals removeClassNamed: className asSymbol.
			^ 'Failed to apply traits: ', anError messageText ].
	^ 'Class defined: ', className
]
