Class {
	#name : 'SpurSweeper',
	#superclass : 'SpurCompactor',
	#category : 'VMMaker-SpurMemoryManager',
	#package : 'VMMaker',
	#tag : 'SpurMemoryManager'
}

{ #category : 'api' }
SpurSweeper >> biasForGC [
]

{ #category : 'api' }
SpurSweeper >> biasForSnapshot [
]

{ #category : 'sweep phase' }
SpurSweeper >> bulkFreeChunkFrom: objOop [
	"The old space entity before objOop is necessarily a marked object. Attempts to free as many bytes 
	from objOop start as possible, looking ahead to free contiguous freechunks / unmarked objects"
	| bytes start next currentObj |
	self assert: ((manager isMarked: objOop) not or: [manager isFreeObject: objOop]).
	start := manager startOfObject: objOop.
	currentObj := objOop.
	bytes := 0.
	[bytes := bytes + (manager bytesInObject: currentObj).
	(manager isRemembered: currentObj)
		ifTrue: 
			[self assert: (manager isFreeObject: currentObj) not.
			 scavenger getFromOldSpaceRememberedSet forgetObject: currentObj].
	next := manager objectStartingAt: start + bytes.
	self assert: ((manager oop: next isLessThan: manager getMemoryMap oldSpaceEnd)
		or: [next = manager getMemoryMap oldSpaceEnd and: [(self canUseAsFreeSpace: next) not]]).
	self canUseAsFreeSpace: next] 
		whileTrue: [currentObj := next].
	
	^self interceptAddFreeChunkWithBytes: bytes at: start
]

{ #category : 'sweep phase' }
SpurSweeper >> canUseAsFreeSpace: objOop [
	<inline: true>
	^ (manager isFreeObject: objOop) or: [(manager isMarked: objOop) not]
]

{ #category : 'api' }
SpurSweeper >> compact [
	<inline: #never> "for profiling"
	self resetFreeLists.
	self globalSweep.
	manager updateSweepEndUsecs
]

{ #category : 'sweep phase' }
SpurSweeper >> globalSweep [
	"Iterate over all entities, in order, making large free chunks from free chunks and unmarked objects, 
	unmarking live objects and rebuilding the free lists."

	| currentEntity |
	currentEntity := manager firstObject.
	[self oop: currentEntity isLessThan: manager getMemoryMap oldSpaceEnd] whileTrue:
		[(self canUseAsFreeSpace: currentEntity) 
			ifTrue: [currentEntity := self bulkFreeChunkFrom: currentEntity]
			ifFalse: [self unmark: currentEntity].
		 currentEntity := manager objectAfter: currentEntity limit: manager getMemoryMap oldSpaceEnd].
			
	manager checkFreeSpace: GCModeFull.
	manager unmarkSurvivingObjectsForCompact.

	
]

{ #category : 'sweep phase' }
SpurSweeper >> interceptAddFreeChunkWithBytes: bytes at: start [
	<inline: true>
	^manager addFreeChunkWithBytes: bytes at: start

]

{ #category : 'api' }
SpurSweeper >> resetFreeLists [
	manager resetFreeListHeads.
	manager totalFreeOldSpace: 0.
]

{ #category : 'sweep phase' }
SpurSweeper >> unmark: objOop [
	self assert: ((manager isMarked: objOop) and: [(manager isFreeObject: objOop) not]).
	(manager isSegmentBridge: objOop) ifFalse: [manager setIsMarkedOf: objOop to: false].
	(manager isPinned: objOop) ifTrue: [manager segmentManager notePinned: objOop]
]
