Class {
	#name : 'ClaudeMcpToolCallLogEntryGroup',
	#superclass : 'Object',
	#traits : 'TGtGroupWithItems',
	#classTraits : 'TGtGroupWithItems classTrait',
	#instVars : [
		'server'
	],
	#category : 'Claude-MCP',
	#package : 'Claude-MCP'
}

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntryGroup >> entries [
	self server ifNil: [ ^ self items ].
	^ self server liveLogEntryItems
]

{ #category : 'views' }
ClaudeMcpToolCallLogEntryGroup >> gtEntriesFor: aView [
	<gtView>
	self entries ifEmpty: [ ^ aView empty ].
	^ aView columnedList
		title: 'Entries';
		priority: 1;
		items: [ self entries ];
		column: '#' text: #index width: 45;
		column: 'Tool' text: #toolName width: 150;
		column: 'Error' text: #errorLabel width: 60;
		column: 'Arguments' text: #argumentSummary;
		column: 'Result' text: #resultSummary;
		send: [ :each | each ];
		actionUpdateButton
]

{ #category : 'printing' }
ClaudeMcpToolCallLogEntryGroup >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: ' (';
		nextPutAll: self entries size asString;
		nextPutAll: ' entries)'
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntryGroup >> server [
	^ server
]

{ #category : 'accessing' }
ClaudeMcpToolCallLogEntryGroup >> server: aClaudeMcpServer [
	server := aClaudeMcpServer
]
