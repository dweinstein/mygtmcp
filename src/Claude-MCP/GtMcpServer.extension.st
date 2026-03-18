Extension { #name : 'GtMcpServer' }

{ #category : '*Claude-MCP' }
GtMcpServer >> clearErrors [
	errors removeAll
]

{ #category : '*Claude-MCP' }
GtMcpServer >> clearHistory [
	history removeAll
]

{ #category : '*Claude-MCP' }
GtMcpServer >> handleRequest: request [
	| jsonRpc response jsonRpcResult |
	request method = 'GET' ifTrue: [
		^ (ZnResponse statusCode: 405)
			headers: (ZnHeaders defaultResponseHeaders);
			yourself ].
	[ jsonRpc := GtMcpJsonRpc on: (STONJSON fromString: request entity contents) ]
		on: Error
		do: [ ^ ZnResponse badRequest: request ].
	[ jsonRpcResult := self dispatch: jsonRpc ]
		on: Error
		do: [ :anError | 
			errors add: anError freeze.
			self isDebug ifTrue: [ anError signal ].
			jsonRpcResult := { 
				'content' -> { { 'type' -> 'text'. 'text' -> ('Error: ', anError class name, ' - ', anError messageText) } asDictionary } asArray. 
				'isError' -> true 
			} asDictionary ].
	"JSON-RPC notifications have no id - return 202 Accepted with empty body"
	jsonRpc id ifNil: [
		| notificationResponse |
		notificationResponse := ZnResponse new.
		notificationResponse statusLine: (ZnStatusLine code: 202).
		history add: request -> notificationResponse.
		^ notificationResponse ].
	response := (GtMcpJsonRpc new
			id: jsonRpc id;
			result: jsonRpcResult) asZnResponse.
	history add: request -> response.
	^ response
]
