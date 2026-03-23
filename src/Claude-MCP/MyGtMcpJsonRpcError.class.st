Class {
	#name : 'MyGtMcpJsonRpcError',
	#superclass : 'Error',
	#instVars : [
		'code',
		'data'
	],
	#category : 'Claude-MCP',
	#package : 'Claude-MCP'
}

{ #category : 'signaling' }
MyGtMcpJsonRpcError class >> signalCode: anInteger message: aString data: anObject [
	| error |
	error := self new.
	error code: anInteger.
	error data: anObject.
	error messageText: aString.
	^ error signal
]

{ #category : 'accessing' }
MyGtMcpJsonRpcError >> code [
	^ code
]

{ #category : 'accessing' }
MyGtMcpJsonRpcError >> code: anInteger [
	code := anInteger
]

{ #category : 'accessing' }
MyGtMcpJsonRpcError >> data [
	^ data ifNil: [ Dictionary new ]
]

{ #category : 'accessing' }
MyGtMcpJsonRpcError >> data: anObject [
	data := anObject
]
