Class {
	#name : 'MyGtMcpDeleteClassTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpDeleteClassTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'className' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('className').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpDeleteClassTool class >> toolDescription [
	^ 'Deletes a class from the image by name. The class must not have subclasses.'
]

{ #category : 'accessing' }
MyGtMcpDeleteClassTool class >> toolName [
	^ 'deleteClass'
]

{ #category : 'execution' }
MyGtMcpDeleteClassTool >> executeWithArguments: arguments [
	| className theClass |
	className := arguments at: 'className'.
	(Smalltalk globals includesKey: className asSymbol)
		ifFalse: [ ^ 'Class not found: ', className ].
	theClass := Smalltalk globals at: className asSymbol.
	theClass subclasses isEmpty
		ifFalse: [ ^ 'Cannot delete class with subclasses: ', className ].
	[ theClass removeFromSystem ]
		on: Error
		do: [ :e | ^ 'Error deleting class: ', e messageText ].
	^ 'Class deleted: ', className
]
