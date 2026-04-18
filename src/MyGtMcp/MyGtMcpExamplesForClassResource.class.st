Class {
	#name : 'MyGtMcpExamplesForClassResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpExamplesForClassResource class >> resourceDescription [
	^ 'List <gtExample> methods defined on a class (instance + class side), with teaser source lines and drill-down URIs.'
]

{ #category : 'accessing' }
MyGtMcpExamplesForClassResource class >> resourceName [
	^ 'Examples in class'
]

{ #category : 'accessing' }
MyGtMcpExamplesForClassResource class >> uriTemplate [
	^ 'gtmcp://examples/{className}'
]

{ #category : 'contents' }
MyGtMcpExamplesForClassResource >> contentsForVariables: aDictionary [
	| className class instanceMethods classMethods renderMethod |
	className := aDictionary at: 'className'.
	class := Smalltalk globals at: className asSymbol ifAbsent: [ nil ].
	class ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'className' -> className} asDictionary ].
	instanceMethods := class methods select: [ :m | m hasPragmaNamed: #gtExample ].
	classMethods := class class methods select: [ :m | m hasPragmaNamed: #gtExample ].
	renderMethod := [ :stream :method :side |
		| first |
		stream nextPutAll: method methodClass name; nextPutAll: '>>#'; nextPutAll: method selector asString.
		stream nextPutAll: ' ['; nextPutAll: side; nextPutAll: ']'; lf.
		first := method sourceCode lines detect: [ :ln | ln trimmed notEmpty ] ifNone: [ '' ].
		stream nextPutAll: '  '; nextPutAll: first trimmed; lf.
		stream nextPutAll: '  uri: gtmcp://examples/'; nextPutAll: className; nextPut: $/; nextPutAll: method selector asString; lf; lf ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Examples in '; nextPutAll: className; nextPutAll: ': '; nextPutAll: (instanceMethods size + classMethods size) asString; lf; lf.
		(instanceMethods asSortedCollection: [ :a :b | a selector < b selector ]) do: [ :m |
			renderMethod value: stream value: m value: 'instance' ].
		(classMethods asSortedCollection: [ :a :b | a selector < b selector ]) do: [ :m |
			renderMethod value: stream value: m value: 'class' ] ]
]

{ #category : 'preview' }
MyGtMcpExamplesForClassResource >> exampleVariables [
	| pragmas method |
	pragmas := Pragma allNamed: #gtExample.
	pragmas isEmpty ifTrue: [ ^ nil ].
	method := pragmas first method.
	^ {'className' -> method methodClass instanceSide name asString} asDictionary
]
