Class {
	#name : 'PrintStringFormatDescriptor',
	#superclass : 'PrintfStringFormatDescriptor',
	#category : 'Printf',
	#package : 'Printf'
}

{ #category : 'rendering' }
PrintStringFormatDescriptor >> applyOperator: object [
	^ object printLeanString
]

{ #category : 'printing' }
PrintStringFormatDescriptor >> printOn: aStream [
	aStream nextPut: $%.
	flush == #leftFlush ifTrue: [aStream nextPut: $-].
	self printWidthOn: aStream.
	aStream nextPut: $p
]
