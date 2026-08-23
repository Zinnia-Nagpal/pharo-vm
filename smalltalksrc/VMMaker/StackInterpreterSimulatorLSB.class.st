Class {
	#name : 'StackInterpreterSimulatorLSB',
	#superclass : 'StackInterpreterSimulator',
	#category : 'VMMaker-InterpreterSimulation',
	#package : 'VMMaker',
	#tag : 'InterpreterSimulation'
}

{ #category : 'memory access' }
StackInterpreterSimulatorLSB >> halfWordHighInLong32: long32 [
	"Used by Balloon"

	^ long32 bitAnd: 16rFFFF
]

{ #category : 'memory access' }
StackInterpreterSimulatorLSB >> halfWordLowInLong32: long32 [
	"Used by Balloon"

	^ long32 bitShift: -16
]

{ #category : 'initialization' }
StackInterpreterSimulatorLSB >> nextShortFrom: aStream [
	"Read a 16-bit quantity from the given (binary) stream."
	^aStream nextLittleEndianNumber: 2
]

{ #category : 'memory access' }
StackInterpreterSimulatorLSB >> vmEndianness [
	"return 0 for little endian, 1 for big endian"
	^0
]
