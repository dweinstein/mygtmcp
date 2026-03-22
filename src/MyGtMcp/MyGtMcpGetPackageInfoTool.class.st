Class {
	#name : 'MyGtMcpGetPackageInfoTool',
	#superclass : 'MyGtMcpTool',
	#category : 'MyGtMcp',
	#package : 'MyGtMcp'
}

{ #category : 'schema' }
MyGtMcpGetPackageInfoTool class >> inputSchema [
	^ {
		'type' -> 'object'.
		'properties' -> {
			'packageName' -> {'type' -> 'string'} asDictionary
		} asDictionary.
		'required' -> #('packageName').
		'additionalProperties' -> false
	} asDictionary
]

{ #category : 'accessing' }
MyGtMcpGetPackageInfoTool class >> toolDescription [
	^ 'Gets information about a package: its classes and their methods.'
]

{ #category : 'accessing' }
MyGtMcpGetPackageInfoTool class >> toolName [
	^ 'getPackageInfo'
]

{ #category : 'execution' }
MyGtMcpGetPackageInfoTool >> executeWithArguments: arguments [
	| pkgName pkg classes |
	pkgName := (arguments at: 'packageName') asSymbol.
	[ pkg := RPackageOrganizer default packageNamed: pkgName ]
		on: Error
		do: [ :e | pkg := nil ].
	pkg ifNil: [ ^ 'Package not found: ', pkgName ].
	classes := pkg definedClasses sorted: [ :a :b | a name < b name ].
	^ String streamContents: [ :stream |
		stream nextPutAll: 'Package: '; nextPutAll: pkg name; cr.
		stream nextPutAll: 'Classes: '; nextPutAll: classes size asString; cr; cr.
		classes do: [ :cls |
			stream nextPutAll: cls name; cr.
			stream nextPutAll: '  superclass: '; nextPutAll: cls superclass name; cr.
			stream nextPutAll: '  ivars: '; nextPutAll: cls instVarNames printString; cr.
			stream nextPutAll: '  methods: '; nextPutAll: cls methods size asString; cr ] ]
]
