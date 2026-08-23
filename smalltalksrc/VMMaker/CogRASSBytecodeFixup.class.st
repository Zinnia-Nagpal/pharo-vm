Class {
	#name : 'CogRASSBytecodeFixup',
	#superclass : 'CogSSBytecodeFixup',
	#instVars : [
		'cogit',
		'mergeSimStack'
	],
	#category : 'VMMaker-JIT',
	#package : 'VMMaker',
	#tag : 'JIT'
}

{ #category : 'translation' }
CogRASSBytecodeFixup class >> filteredInstVarNames [
	"Override to group char and short vars together for compactness.
	 self typedef"
	| vars |
	vars := super filteredInstVarNames asOrderedCollection.
	vars
		remove: 'mergeSimStack';
		add: 'mergeSimStack' afterIndex: (vars indexOf: 'targetInstruction').
	^vars
]

{ #category : 'instance creation' }
CogRASSBytecodeFixup class >> for: aCogit [
	^self new cogit: aCogit
]

{ #category : 'initialize-release' }
CogRASSBytecodeFixup >> cogit: aCogit [
	cogit := aCogit.
	^self
]

{ #category : 'debug printing' }
CogRASSBytecodeFixup >> hasMergeSimStack [
	^self needsFixup and: [mergeSimStack notNil]
]

{ #category : 'accessing' }
CogRASSBytecodeFixup >> mergeSimStack [
	<returnTypeC: #'CogSimStackEntry *'>
	^mergeSimStack
]

{ #category : 'accessing' }
CogRASSBytecodeFixup >> mergeSimStack: anObject [

	^mergeSimStack := anObject
]

{ #category : 'debug printing' }
CogRASSBytecodeFixup >> printStateOn: aStream [
	<doNotGenerate>
	(targetInstruction isNil and: [simStackPtr isNil]) ifTrue:
		[^self].
	super printStateOn: aStream.
	mergeSimStack ifNotNil:
		[aStream skip: -1; space; nextPut: $(.
		 cogit printSimStack: mergeSimStack toDepth: simStackPtr spillBase: -1 on: aStream.
		 aStream nextPut: $); nextPut: $)]
]

{ #category : 'accessing' }
CogRASSBytecodeFixup >> reinitialize [
	<inline: true>
	super reinitialize.
	mergeSimStack := nil
]

{ #category : 'debug printing' }
CogRASSBytecodeFixup >> simStackPrintString [
	<doNotGenerate>
	^String streamContents:
		[:s|
		 self notAFixup
			ifTrue: [s nextPutAll: 'notAFixup']
			ifFalse: [cogit printSimStack: mergeSimStack toDepth: simStackPtr spillBase: -1 on: s]]
]
