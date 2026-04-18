Class {
	#name : 'MyGtMcpExampleMethodResource',
	#superclass : 'MyGtMcpResource',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'accessing' }
MyGtMcpExampleMethodResource class >> resourceDescription [
	^ 'Read the source of a single <gtExample> method on a class (instance or class side).'
]

{ #category : 'accessing' }
MyGtMcpExampleMethodResource class >> resourceName [
	^ 'Example method source'
]

{ #category : 'accessing' }
MyGtMcpExampleMethodResource class >> uriTemplate [
	^ 'gtmcp://examples/{className}/{selector}'
]

{ #category : 'contents' }
MyGtMcpExampleMethodResource >> contentsForVariables: aDictionary [
	| className selector class selectorSymbol method side protocolName packageName normalizedSource |
	className := aDictionary at: 'className'.
	selector := aDictionary at: 'selector'.
	class := Smalltalk globals at: className asSymbol ifAbsent: [ nil ].
	class ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'className' -> className} asDictionary ].
	selectorSymbol := selector asSymbol.
	method := class methodDict at: selectorSymbol ifAbsent: [ nil ].
	method
		ifNotNil: [ side := 'instance' ]
		ifNil: [
			method := class class methodDict at: selectorSymbol ifAbsent: [ nil ].
			method ifNotNil: [ side := 'class' ] ].
	method ifNil: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Resource not found'
			data: {'className' -> className. 'selector' -> selector} asDictionary ].
	(method hasPragmaNamed: #gtExample) ifFalse: [
		MyGtMcpJsonRpcError
			signalCode: -32002
			message: 'Not a <gtExample>'
			data: {'className' -> className. 'selector' -> selector. 'side' -> side} asDictionary ].
	protocolName := (method respondsTo: #protocolName)
		ifTrue: [ method protocolName ifNil: [ '(none)' ] ]
		ifFalse: [ method category ifNil: [ '(none)' ] ].
	packageName := method package ifNil: [ '(none)' ] ifNotNil: [ :p | p name ].
	normalizedSource := method sourceCode copyReplaceAll: String cr with: String lf.
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Example: '; nextPutAll: method methodClass name; nextPutAll: '>>#'; nextPutAll: method selector asString; lf.
		stream nextPutAll: 'Side: '; nextPutAll: side; lf.
		stream nextPutAll: 'Protocol: '; nextPutAll: protocolName asString; lf.
		stream nextPutAll: 'Package: '; nextPutAll: packageName asString; lf; lf.
		stream nextPutAll: normalizedSource ]
]

{ #category : 'preview' }
MyGtMcpExampleMethodResource >> exampleVariables [
	| pragmas pragma method |
	pragmas := Pragma allNamed: #gtExample.
	pragmas isEmpty ifTrue: [ ^ nil ].
	pragma := pragmas first.
	method := pragma method.
	^ {
		'className' -> method methodClass instanceSide name asString.
		'selector' -> method selector asString } asDictionary
]
