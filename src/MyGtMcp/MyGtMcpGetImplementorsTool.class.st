Class {
	#name : 'MyGtMcpGetImplementorsTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpGetImplementorsTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'methodName' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('methodName').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpGetImplementorsTool class >> toolDescription [
	^ 'Gets a method by name and returns a list of methods that implement it.'
]

{ #category : 'accessing' }
MyGtMcpGetImplementorsTool class >> toolName [
	^ 'getImplementors'
]

{ #category : 'execution' }
MyGtMcpGetImplementorsTool >> executeWithArguments: arguments [
	^ [ Character cr join:
		((arguments at: 'methodName') asSymbol gtImplementors result toArray wait collect: #name) ]
		on: Error
		do: [ :e | 'Error looking up implementors: ', e messageText ]
]
