Class {
	#name : 'CArrayOfLongsAccessor',
	#superclass : 'CObjectAccessor',
	#instVars : [
		'objectMemory',
		'address',
		'elementByteSize'
	],
	#category : 'Slang-Types',
	#package : 'Slang',
	#tag : 'Types'
}

{ #category : 'accessing' }
CArrayOfLongsAccessor >> address [
	^address
]

{ #category : 'accessing' }
CArrayOfLongsAccessor >> at: index [
	"Map at: into a suitably aligned and offset longAt:, for accessing Arrays stored in the heap, such as the primTraceLog."
	^objectMemory longAt: index * elementByteSize + address
]

{ #category : 'accessing' }
CArrayOfLongsAccessor >> at: index put: aValue [
	"Map at:put: into a suitably aligned and offset longAt:put:, for accessing Arrays stored in the heap, such as the primTraceLog."
	^objectMemory longAt: index * elementByteSize + address put: aValue
]

{ #category : 'initialize-release' }
CArrayOfLongsAccessor >> objectMemory: anObjectMemory at: anAddress [
	objectMemory := anObjectMemory.
	object := anObjectMemory memoryManager.
	offset := anAddress / anObjectMemory wordSize.
	elementByteSize := anObjectMemory wordSize.
	address := anAddress
]
