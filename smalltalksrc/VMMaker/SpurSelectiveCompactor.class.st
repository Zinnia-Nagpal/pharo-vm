Class {
	#name : 'SpurSelectiveCompactor',
	#superclass : 'SpurSweeper',
	#instVars : [
		'segmentToFill',
		'lastLilliputianChunk'
	],
	#classVars : [
		'MaxOccupationForCompaction'
	],
	#category : 'VMMaker-SpurMemoryManager',
	#package : 'VMMaker',
	#tag : 'SpurMemoryManager'
}

{ #category : 'translation' }
SpurSelectiveCompactor class >> declareCVarsIn: aCCodeGenerator [
	super declareCVarsIn: aCCodeGenerator.
	aCCodeGenerator var: 'segmentToFill' type: #'SpurSegmentInfo *'
]

{ #category : 'initialization' }
SpurSelectiveCompactor class >> initialize [
	super initialize.
	"If the segment is occupied by more than MaxOccupationForCompaction, 
	 it's not worth compacting it, whatever the rest of the system looks like.
	 MaxOccupationForCompaction is included in [0;16rFFFF]."
	MaxOccupationForCompaction := 16rD000. "81%"
]

{ #category : 'simulation' }
SpurSelectiveCompactor class >> simulatorClass [
	^ SpurSelectiveCompactor"Simulator"
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> assertNoSegmentBeingCompacted [
	"Assertion only - no segment is being claimed at this point"
	| segInfo |
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	0 to: manager numSegments - 1 do:
		[:i|
		 segInfo := self addressOf: (manager segmentManager segments at: i).
		 self deny: (self isSegmentBeingCompacted: segInfo)].
	
]

{ #category : 'api' }
SpurSelectiveCompactor >> compact [
	<inline: #never> "for profiling, though we profile selectiveCompaction and sweep separatly."
	self resetFreeLists.
	self freePastSegmentsAndSetSegmentToFill.
	self globalSweepAndSegmentOccupationAnalysis.
	self assert: self sortedLilliputianChunks.
	manager updateSweepEndUsecs.
	self selectiveCompaction.
	
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> compactSegment: segInfo freeStart: initialFreeStart segIndex: segIndex [
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	| currentEntity fillStart bytesToCopy bridge copy |
	fillStart := initialFreeStart.
	bridge := manager segmentManager bridgeFor: segInfo.
	currentEntity := manager objectStartingAt: segInfo segStart.
	self deny: segIndex = 0. "Cannot compact seg 0"
	lastLilliputianChunk := self lastLilliputianChunkAtIndex: segIndex - 1.
	[self oop: currentEntity isLessThan: bridge] whileTrue:
		[(manager isFreeObject: currentEntity)
			ifTrue: 
				["To avoid confusing too much Spur (especially the leak/free checks), we mark the free chunk as a word object."
				 (manager isLilliputianSize: (manager bytesInObject: currentEntity)) 
					ifTrue: [self incrementalUnlinkLilliputianChunk: currentEntity] "Performance hack for single linked list"
					ifFalse: [manager detachFreeObject: currentEntity].
				 manager set: currentEntity classIndexTo: manager wordSizeClassIndexPun formatTo: manager wordIndexableFormat]
			ifFalse: 
				["Copy the object in segmentToFill and replace it by a forwarder."
				 self assert: (manager isPinned: currentEntity) not. 
				 bytesToCopy := manager bytesInObject: currentEntity.
				 manager memcpy: fillStart asVoidPointer _: (manager startOfObject: currentEntity) asVoidPointer _: bytesToCopy.
				 copy := manager objectStartingAt: fillStart.
				 (manager isRemembered: copy) ifTrue: 
					["copy has the remembered bit set, but is not in the remembered table."
					 manager setIsRememberedOf: copy to: false.
					 self getFromOldSpaceRememberedSet remember: copy].
				 manager forward: currentEntity to: (manager objectStartingAt: fillStart).
				 fillStart := fillStart + bytesToCopy.
				 self assert: (self oop: fillStart isLessThan: (segmentToFill segLimit - manager bridgeSize))].
		 currentEntity := manager objectAfter: currentEntity limit: manager getMemoryMap oldSpaceEnd].
	self assert: currentEntity = bridge.
	^ fillStart
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> compactSegmentsToCompact [
	"Forwards all objects in segments to compact and removes their freechunks"
	| segInfo fillStart |
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	fillStart := segmentToFill segStart.
	
	 "Removes initial free chunk in segment to fill... (Segment is entirely free)"
	manager detachFreeObject: (manager objectStartingAt: fillStart).
	
	 "Compact each segment to compact..."
	0 to: manager numSegments - 1 do:
		[:i| 
		 segInfo := self addressOf: (manager segmentManager segments at: i).
		(self isSegmentBeingCompacted: segInfo)
			ifTrue: [fillStart := self compactSegment: segInfo freeStart: fillStart segIndex: i]].
		
	 "Final free chunk in segment to fill..."
	 manager 
		addFreeChunkWithBytes: segmentToFill segSize - manager bridgeSize + segmentToFill segStart - fillStart 
		at: fillStart.
	
	self postCompactionAction
	
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> computeSegmentsToCompact [
	"Compute segments to compact: least occupied.
	 Answers true if compaction should be done 
	 (at least 1 segment is being compacted and
	 there is a segment to compact into)."
	| canStillClaim aboutToClaim aboutToClaimSegment atLeastOneSegmentToCompact |
	<var: 'aboutToClaimSegment' type: #'SpurSegmentInfo *'>
	atLeastOneSegmentToCompact := false.
	aboutToClaimSegment := self findNextSegmentToCompact.
	"Segment to fill is one of the segment compacted last GC. 
	 If no segment were compacted last GC, and that there is 
	 at least one segment to compact, allocate a new one."
	aboutToClaimSegment ifNil: [^false].
	segmentToFill ifNil:
		[self findOrAllocateSegmentToFill.
		 segmentToFill ifNil: ["Abort compaction"^false]].
	canStillClaim := segmentToFill segSize - manager bridgeSize.
	[aboutToClaimSegment ifNil: [^atLeastOneSegmentToCompact].
	 aboutToClaim := self sizeClaimedIn: aboutToClaimSegment.
	 aboutToClaim < canStillClaim ] whileTrue: 
		[self markSegmentAsBeingCompacted: aboutToClaimSegment.
		 atLeastOneSegmentToCompact := true.
		 canStillClaim := canStillClaim - aboutToClaim.
		 aboutToClaimSegment := self findNextSegmentToCompact].
	^atLeastOneSegmentToCompact
]

{ #category : 'segment to fill' }
SpurSelectiveCompactor >> findAndSetSegmentToFill [
	| segInfo firstEntity |
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	0 to: manager numSegments - 1 do:
		[:i| 
		 segInfo := self addressOf: (manager segmentManager segments at: i).
		 firstEntity := manager objectStartingAt: segInfo segStart.
		 ((manager isFreeObject: firstEntity) and: [(manager objectAfter: firstEntity limit: manager getMemoryMap oldSpaceEnd) = (manager segmentManager bridgeFor: segInfo)])
			ifTrue: [segmentToFill := segInfo. ^i]].
	^-1
	
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> findNextSegmentToCompact [
	"Answers the next segment to compact or nil if none.
	  The next segment to compact:
	 - cannot be segment 0 (Segment 0 has specific objects 
	  (nil, true, etc.) and special size computed at start-up 
	  that we don't want to deal with)
	 - cannot have a high occupation rate (> MaxOccupationForCompaction)"
	| leastOccupied leastOccupiedSegment tempOccupied segInfo |
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	leastOccupied := 16rFFFF.
	1 to: manager numSegments - 1 do:
		[:i|
		 segInfo := self addressOf: (manager segmentManager segments at: i).
		 ((self isSegmentBeingCompacted: segInfo) or: [segInfo containsPinned or: [manager segmentManager isEmptySegment: segInfo] ])
			ifFalse: 
				[(tempOccupied := self occupationOf: segInfo) <= leastOccupied
					ifTrue: [ leastOccupied := tempOccupied.
							 leastOccupiedSegment := segInfo ]]].
	leastOccupied > MaxOccupationForCompaction ifTrue:
		[^self cCoerceSimple: nil to: #'SpurSegmentInfo *'].
	^leastOccupiedSegment
]

{ #category : 'segment to fill' }
SpurSelectiveCompactor >> findOrAllocateSegmentToFill [
	"There was no compacted segments from past GC that we can directly re-use.
	 We need either to find an empty segment or allocate a new one."

	| segIndex |
	self findAndSetSegmentToFill.
	segmentToFill ifNotNil: [ ^ 0 ].
	"No empty segment. We need to allocate a new one"
	(manager
		 growOldSpaceByAtLeast: manager growHeadroom
		 callingOperation: 'finding or allocating segment to fill') ifNil: [ "failed to allocate"
		^ 0 ].
	"We don't know which segment it is that we've just allocated... So we look for it... This is a bit dumb."
	segIndex := self findAndSetSegmentToFill.
	"Lilliputian performance hack management... Last lilliputian of new segment is same as prev because no lilliputian in new segment"
	self
		setLastLilliputianChunkAtindex: segIndex
		to: (self lastLilliputianChunkAtIndex: segIndex - 1).
	self assert: segmentToFill ~~ nil
]

{ #category : 'segment access' }
SpurSelectiveCompactor >> freePastSegmentsAndSetSegmentToFill [	
	"The first segment being claimed met becomes the segmentToFill. The others are just freed."
	| segInfo |
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	segmentToFill := nil.
	0 to: manager numSegments - 1 do:
		[:i|
		 segInfo := self addressOf: (manager segmentManager segments at: i).
		 (self isSegmentBeingCompacted: segInfo)
			ifTrue: 
				[manager 
					initFreeChunkWithBytes: segInfo segSize - manager bridgeSize 
					at: segInfo segStart.
				 segmentToFill ifNil: [segmentToFill := segInfo]]]
]

{ #category : 'sweep phase' }
SpurSelectiveCompactor >> globalSweepAndSegmentOccupationAnalysis [
	<inline: #never> "profiling"
	"Iterate over old space, free unmarked objects, annotate each segment with each occupation"
	| currentEntity nextBridge segmentIndex currentUsed currentUnused |
	lastLilliputianChunk := 0. "performance hack for single linked list"
	currentEntity := manager firstObject.
	nextBridge := manager segmentManager bridgeAt: 0.
	segmentIndex := currentUnused := currentUsed := 0.
	self setLastLilliputianChunkAtindex: 0 to: 0.
	[self oop: currentEntity isLessThan: manager getMemoryMap oldSpaceEnd] whileTrue:
		[currentEntity = nextBridge "End of segment, set occupation"
			ifTrue: 
				[self 
					setOccupationAtIndex: segmentIndex
					used: currentUsed 
					unused: currentUnused.
				  self setLastLilliputianChunkAtindex: segmentIndex to: lastLilliputianChunk.
				  currentUnused := currentUsed := 0.
				  segmentIndex := segmentIndex + 1.
				  nextBridge := manager segmentManager bridgeAt: segmentIndex]
			ifFalse: 
				[(self canUseAsFreeSpace: currentEntity) "In-segment, sweep and compute occupation"
					ifTrue: 
						[currentEntity := self bulkFreeChunkFrom: currentEntity.
						 currentUnused := currentUnused + (manager bytesInObject: currentEntity)]
					ifFalse: 
						[self unmark: currentEntity.
						 currentUsed := currentUsed + (manager bytesInObject: currentEntity)]].
		 currentEntity := manager objectAfter: currentEntity limit: manager getMemoryMap oldSpaceEnd].
	"set last segment details"	
	self 
		setOccupationAtIndex: segmentIndex
		used: currentUsed 
		unused: currentUnused.
	self setLastLilliputianChunkAtindex: segmentIndex to: lastLilliputianChunk.
	"we set the nextFreeChunk of last chunk at the end of the loop to avoid to set it at each iteration"
	lastLilliputianChunk ~= 0 ifTrue:
	 	[manager setNextFreeChunkOf: lastLilliputianChunk withValue: 0 isLilliputianSize: true].
		
	manager checkFreeSpace: GCModeFull.
	manager unmarkSurvivingObjectsForCompact.
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> incrementalLilliputianSmallChunk: freeChunk [
	"This is duplicate form #unlinkSmallChunk:index: for performance hack (single iteration of single linked list)"
	<inline: #never> "for profiling"
	| node next |
	self assert: (manager bytesInObject: freeChunk) = (manager baseHeaderSize + manager allocationUnit).
	self assert: manager lilliputianChunkIndex = ((manager bytesInObject: freeChunk) / manager allocationUnit).
	lastLilliputianChunk = 0 ifTrue: "first incremental unlink"
		[(freeChunk = manager firstLilliputianChunk) 
			ifTrue: [^manager unlinkFreeChunk: freeChunk atIndex: manager lilliputianChunkIndex isLilliputianSize: true]
			ifFalse: [lastLilliputianChunk := manager firstLilliputianChunk]].
	 node := manager fetchPointer: manager freeChunkNextIndex ofFreeChunk: lastLilliputianChunk.
	 [node ~= 0] whileTrue:
		[self assert: node = (manager startOfObject: node).
		 manager assertValidFreeObject: node.
		 next := manager fetchPointer: manager freeChunkNextIndex ofFreeChunk: node.
		 node = freeChunk ifTrue:
			[^manager setNextFreeChunkOf: lastLilliputianChunk withValue: next isLilliputianSize: true].
		 lastLilliputianChunk := node.
		 node := next].
	 self error: 'freeChunk not found in lilliputian chunk free list'

	

]

{ #category : 'sweep phase' }
SpurSelectiveCompactor >> interceptAddFreeChunkWithBytes: bytes at: start [
	<inline: true>
	| freeChunk |
	(manager isLilliputianSize: bytes) ifTrue: "build size 1 free chunk in ascending addresses order"
		[lastLilliputianChunk = 0
			ifTrue: [^lastLilliputianChunk := manager addFreeChunkWithBytes: bytes at: start]
			ifFalse: 
				[manager increaseFreeOldSpaceBy: bytes.
				 freeChunk := manager initFreeChunkWithBytes: bytes at: start.
				 manager setNextFreeChunkOf: lastLilliputianChunk withValue: freeChunk isLilliputianSize: true.
				 "we set the nextFreeChunk of last chunk at the end of the loop to avoid to set it at each iteration"
				 ^lastLilliputianChunk := freeChunk]].
	^manager addFreeChunkWithBytes: bytes at: start

]

{ #category : 'segment access' }
SpurSelectiveCompactor >> isSegmentBeingCompacted: segInfo [ 
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	"Swizzle is abused bit 16 isBeingCompacted bits 0-15 occupation"
	^ segInfo swizzle anyMask: 1 << 16
]

{ #category : 'segment access' }
SpurSelectiveCompactor >> lastLilliputianChunkAtIndex: segIndex [
	<inline: true>
	"Abuse lastFreeObject field, can be used during compaction only, used for different purpose during snapshot"
	^(self addressOf: (manager segmentManager segments at: 0)) lastFreeObject
]

{ #category : 'segment access' }
SpurSelectiveCompactor >> markSegmentAsBeingCompacted: segInfo [ 
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	"Swizzle is abused bit 16 isBeingCompacted bits 0-15 occupation"
	segInfo swizzle: (segInfo swizzle bitOr: 1 << 16)
]

{ #category : 'segment access' }
SpurSelectiveCompactor >> occupationOf: segInfo [ 
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	"Swizzle is abused bit 16 isBeingCompacted bits 0-15 occupation"
	^segInfo swizzle bitAnd: 16rFFFF
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> postCompactionAction [
	| allFlags |
	"For now we don't optimize and just follow everything everywhere on stack and in caches, let's see in the profiler if we need to optimize with those cases. My guess is that this is < 100 microSecond"
	manager followSpecialObjectsOop.
	allFlags := BecamePointerObjectFlag + BecameActiveClassFlag bitOr: BecameCompiledMethodFlag.
	"Note: there is not the OldBecameNewFlag"
	"gcMode flag is cleared after postBecomeAction, reset it."
	manager coInterpreter postBecomeAction: allFlags.
	manager coInterpreter setGCMode: GCModeFull.
	
	"Special to selective, crazy objects can be forwarded..."
	"manager postBecomeScanClassTable: allFlags. => Done in followClassTable"
	manager followClassTable.
	manager followProcessList.
	manager followForwardedObjStacks.
	
	"Not sure the following are needed...
	coInterpreter mapInterpreterOops.
	manager mapExtraRoots."
	self assert: manager validClassTableHashes.
]

{ #category : 'api' }
SpurSelectiveCompactor >> postSwizzleAction [
	"Since the compact abuses the swizzle field of segment, it needs to be reset after start-up."
	| segInfo |
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	0 to: manager numSegments - 1 do:
		[:i|
		 segInfo := self addressOf: (manager segmentManager segments at: i).
		 segInfo swizzle: 0 ]
]

{ #category : 'compaction' }
SpurSelectiveCompactor >> selectiveCompaction [
	"Figures out which segments to compact and compact them into segmentToFill"
	| shouldCompact |
	<inline: #never> "profiling"
	self assertNoSegmentBeingCompacted.
	"Should compact only if there is at least 1 segment to compact 
	 and there is a segment to compact into"
	shouldCompact := self computeSegmentsToCompact.
	"If no compaction we don't pay forwarding cost (stack scan, cache scan, etc.)
	 and we don't allocate segmentToFill if none available."
	shouldCompact ifTrue:
		[self assert: segmentToFill ~~ nil.
		 self compactSegmentsToCompact].
	manager checkFreeSpace: GCModeFull.
]

{ #category : 'segment access' }
SpurSelectiveCompactor >> setLastLilliputianChunkAtindex: segIndex to: chunk [ 
	<inline: true>
	"Abuse lastFreeObject field, can be used during compaction only, used for different purpose during snapshot"
	(self addressOf: (manager segmentManager segments at: 0)) lastFreeObject: chunk
]

{ #category : 'segment access' }
SpurSelectiveCompactor >> setOccupationAtIndex: segmentIndex used: used unused: unused [
	"WARNING: Resets the isCompacted bit"
	"Swizzle is abused bit 16 isBeingCompacted bits 0-15 occupation
	 Setting occupation resets the claim bit"
	| occupation segInfo |
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	segInfo := self addressOf: (manager segmentManager segments at: segmentIndex).
	"careful with overflow here..."
	occupation := ((used asFloat / (used + unused)) * 16rFFFF) asInteger.
	self assert: (occupation between: 0 and: 16rFFFF).
	segInfo swizzle: occupation
]

{ #category : 'segment access' }
SpurSelectiveCompactor >> sizeClaimedIn: segment [ 
	<var: 'segment' type: #'SpurSegmentInfo *'>
	<var: 'ratio' type: #'double'>
	"careful with overflow here"
	"roundedup used ratio (+1 to round up)"
	| ratio |
	ratio := ((self occupationOf: segment) + 1) asFloat / 16rFFFF.
	^(ratio * (segment segSize - manager bridgeSize)) asInteger 
]

{ #category : 'sweep phase' }
SpurSelectiveCompactor >> sortedLilliputianChunks [
	|current next|
	current := manager firstLilliputianChunk.
	current = 0 ifTrue: [^true]. "no node"
	[next := manager fetchPointer: manager freeChunkNextIndex ofFreeChunk: current.
	 next = 0] whileFalse:
		[(manager oop: current isLessThan: next) ifFalse: [^false].
		 current := next].
	^ true

]

{ #category : 'segment access' }
SpurSelectiveCompactor >> unmarkSegmentAsBeingCompacted: segInfo [ 
	<inline: true> "So it is not generated if unused"
	<var: 'segInfo' type: #'SpurSegmentInfo *'>
	"Swizzle is abused bit 16 isBeingCompacted bits 0-15 occupation"
	segInfo swizzle: (segInfo swizzle bitAnd: 16rFFFF)
]
