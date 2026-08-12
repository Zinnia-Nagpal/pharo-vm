Class {
	#name : 'CogVMSimulatorLSB',
	#superclass : 'CogVMSimulator',
	#category : 'VMMaker-JITSimulation',
	#package : 'VMMaker',
	#tag : 'JITSimulation'
}

{ #category : 'memory access' }
CogVMSimulatorLSB >> byteAt: byteAddress put: byte [
	^objectMemory byteAt: byteAddress put: byte
]

{ #category : 'memory access' }
CogVMSimulatorLSB >> halfWordHighInLong32: long32 [
	"Used by Balloon"

	^ long32 bitAnd: 16rFFFF
]

{ #category : 'memory access' }
CogVMSimulatorLSB >> halfWordLowInLong32: long32 [
	"Used by Balloon"

	^ long32 bitShift: -16
]

{ #category : 'initialization' }
CogVMSimulatorLSB >> nextShortFrom: aStream [
	"Read a 16-bit quantity from the given (binary) stream."
	^aStream nextLittleEndianNumber: 2
]

{ #category : 'memory access' }
CogVMSimulatorLSB >> vmEndianness [
	"return 0 for little endian, 1 for big endian"
	^0
]
