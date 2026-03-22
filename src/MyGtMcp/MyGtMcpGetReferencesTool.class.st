Class {
	#name : 'MyGtMcpGetReferencesTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpGetReferencesTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'name' -> {'type' -> 'string'} asDictionary.
			'type' -> {
				'type' -> 'string'.
				'enum' -> #('class' 'selector')
			} asDictionary
		} asDictionary.
		'required' -> #('name' 'type').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpGetReferencesTool class >> toolDescription [
	^ 'Gets references to a name. Type can be "class" (all references to a class) or "selector" (all senders of a selector). Returns a list of method references.'
]

{ #category : 'accessing' }
MyGtMcpGetReferencesTool class >> toolName [
	^ 'getReferences'
]

{ #category : 'execution' }
MyGtMcpGetReferencesTool >> executeWithArguments: arguments [
	| name type results |
	name := arguments at: 'name'.
	type := arguments at: 'type'.
	results := [
		type = 'class'
			ifTrue: [
				| classSymbol theClass binding |
				classSymbol := name asSymbol.
				(Smalltalk globals includesKey: classSymbol) ifFalse: [ ^ 'Class not found: ', name ].
				theClass := Smalltalk globals at: classSymbol.
				binding := theClass binding.
				SystemNavigation default allReferencesTo: binding ]
			ifFalse: [
				type = 'selector'
					ifTrue: [ SystemNavigation default allSendersOf: name asSymbol ]
					ifFalse: [ ^ 'Invalid type: ', type, '. Must be "class" or "selector".' ] ] ]
			on: Error
			do: [ :e | ^ 'Error finding references: ', e messageText ].
	results isEmpty ifTrue: [ ^ 'No references found' ].
	^ Character cr join: (results collect: [ :method |
		method methodClass name, '>>#', method selector ])
]
