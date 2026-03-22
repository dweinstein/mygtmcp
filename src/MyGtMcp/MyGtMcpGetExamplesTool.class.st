Class {
	#name : 'MyGtMcpGetExamplesTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpGetExamplesTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'name' -> {'type' -> 'string'} asDictionary.
			'type' -> {
				'type' -> 'string'.
				'enum' -> #('class' 'package')
			} asDictionary
		} asDictionary.
		'required' -> #('name').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpGetExamplesTool class >> toolDescription [
	^ 'Gets gtExample methods. Type can be "class" (examples defined in that class, including inherited) or "package" (all examples in package). Returns method names and first lines of code.'
]

{ #category : 'accessing' }
MyGtMcpGetExamplesTool class >> toolName [
	^ 'getExamples'
]

{ #category : 'execution' }
MyGtMcpGetExamplesTool >> executeWithArguments: arguments [
	| name type examples |
	name := arguments at: 'name'.
	type := arguments at: 'type' ifAbsent: [ 'class' ].
	[ examples := type = 'package'
		ifTrue: [
			| pkg |
			pkg := RPackageOrganizer default packageNamed: name asSymbol.
			pkg definedClasses flatCollect: [ :cls |
				(cls methods, cls class methods) select: [ :method | method hasPragmaNamed: #gtExample ] ] ]
		ifFalse: [
			| cls |
			cls := Smalltalk globals at: name asSymbol.
			(((Pragma allNamed: #gtExample from: cls to: Object),
				(Pragma allNamed: #gtExample from: cls class to: Object class))
					reject: [ :pragma | pragma method methodClass instanceSide == Object ])
				collect: [ :pragma | pragma method ] ] ]
		on: Error
		do: [ :e | examples := nil ].
	examples ifNil: [ ^ 'Not found: ', name, ' (type: ', type, ')' ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Examples: '; nextPutAll: examples size asString; cr; cr.
		examples do: [ :method |
			stream nextPutAll: method methodClass name; nextPutAll: '>>#'; nextPutAll: method selector; cr.
			stream nextPutAll: '  '; nextPutAll: (method sourceCode lines first: (3 min: method sourceCode lines size)) asString; cr; cr ] ]
]
