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

{ #category : '*Claude-MCP' }
GtMcpServer >> handleToolsCall: aJsonRpc [
	| tool result arguments |
	tool := tools detect: [ :t | t name = (aJsonRpc params at: 'name') ].
	arguments := aJsonRpc params at: 'arguments' ifAbsent: [ Dictionary new ].
	result := tool performToolCall: (GtLlmFunctionToolCall new
		name: (aJsonRpc params at: 'name');
		arguments: arguments).
	(result isArray and: [ result allSatisfy: #isDictionary ])
		ifTrue: [ ^ { 'isError' -> false. 'content' -> result } asDictionary ].
	^ { 'isError' -> false.
		'content' -> {
			{ 'type' -> 'text'. 'text' -> result asString } asDictionary
		} } asDictionary
]

{ #category : '*Claude-MCP' }
GtMcpServer >> handleToolsList: _ [
	^ {'tools'
			-> (tools
					collect: [ :aTool |
						| inputSchema |
						inputSchema := (aTool respondsTo: #inputSchema)
							ifTrue: [ aTool inputSchema ]
							ifFalse: [
								{'type' -> 'object'.
									'properties'
										-> (aTool parameters
												collect: [ :aString |
													aString
														-> {'type' -> 'string'.
															'description' -> aString} asDictionary ]) asDictionary.
									'required' -> aTool parameters.
									'additionalProperties' -> false} asDictionary ].
						{'name' -> aTool name.
							'title' -> aTool name.
							'description' -> aTool description.
							'inputSchema' -> inputSchema} asDictionary ]) asArray}
		asDictionary
]
