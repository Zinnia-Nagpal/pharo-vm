Class {
	#name : 'ObjectProxyForTranslatedPrimitiveSimulation',
	#superclass : 'Object',
	#instVars : [
		'interpreter',
		'oop',
		'unitSize'
	],
	#category : 'VMMaker-InterpreterSimulation',
	#package : 'VMMaker',
	#tag : 'InterpreterSimulation'
}

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> at: index [
	self assert: (index between: 1 and: self size).
	unitSize = 1 ifTrue: [^interpreter fetchByte: index - 1 ofObject: oop].
	unitSize = 2 ifTrue: [^interpreter fetchShort16: index - 1 ofObject: oop].
	unitSize = 4 ifTrue: [^interpreter fetchLong32: index - 1 ofObject: oop].
	unitSize = 8 ifTrue: [^interpreter fetchLong64: index - 1 ofObject: oop].
	self halt: 'Can''t handle unitSize ', unitSize printString
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> at: index put: val [
	self assert: (index between: 1 and: self size).
	unitSize = 1 ifTrue: [^ interpreter storeByte: index - 1 ofObject: oop withValue: val].
	unitSize = 2 ifTrue: [^ interpreter storeShort16: index - 1 ofObject: oop withValue: val].
	unitSize = 4 ifTrue: [^ interpreter storeLong32: index - 1 ofObject: oop withValue: val].
	unitSize = 8 ifTrue: [^ interpreter storeLong64: index - 1 ofObject: oop withValue: val].
	self halt: 'Can''t handle unitSize ', unitSize printString
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> basicAt: offset [
	^self at: offset
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> basicAt: offset put: val [
	^self at: offset put: val
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> basicSize [
	^self size
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> interpreter [

	^ interpreter
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> interpreter: anObject [

	interpreter := anObject
]

{ #category : 'initialize-release' }
ObjectProxyForTranslatedPrimitiveSimulation >> interpreter:  anInterpreter oop: objOop unitSize: baseTypeSize [
	interpreter := anInterpreter.
	oop := objOop.
	unitSize := baseTypeSize
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> oop [

	^ oop
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> oop: anObject [

	oop := anObject
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> size [
	unitSize = 1 ifTrue: [^interpreter numBytesOf: oop].
	unitSize = 2 ifTrue: [^interpreter num16BitUnitsOf: oop].
	unitSize = 4 ifTrue: [^interpreter num32BitUnitsOf: oop].
	unitSize = 8 ifTrue: [^interpreter num64BitUnitsOf: oop].
	self halt: 'Can''t handle unitSize ', unitSize printString
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> unitSize [

	^ unitSize
]

{ #category : 'accessing' }
ObjectProxyForTranslatedPrimitiveSimulation >> unitSize: anObject [

	unitSize := anObject
]
