Class {
	#name : 'SpurCompactor',
	#superclass : 'VMClass',
	#instVars : [
		'coInterpreter',
		'manager',
		'scavenger'
	],
	#pools : [
		'SpurMemoryManagementConstants',
		'VMBasicConstants',
		'VMSpurObjectRepresentationConstants'
	],
	#category : 'VMMaker-SpurMemoryManager',
	#package : 'VMMaker',
	#tag : 'SpurMemoryManager'
}

{ #category : 'translation' }
SpurCompactor class >> classesForTranslation [
	"Usually we want to add the SpurCompactor first, followed by the subclass.
	 SpurHybridCompactor is more complicated."
	^(self withAllSuperclasses copyUpThrough: SpurCompactor) reverse
]

{ #category : 'translation' }
SpurCompactor class >> declareCVarsIn: aCCodeGenerator [
	"If subclasses are being used but are not the compactorClass itself
	 then statically resolve their api selectors."
	(self inheritsFrom: SpurCompactor) ifTrue: "leave SpurCompactor methods alone"
		[(SpurMemoryManager compactorClass includesBehavior: self) ifFalse: "only map methods not in the compactorClass"
			[#(compact biasForGC biasForSnapshot remapObj: shouldRemapObj:) do: "map the public api methods only"
				[:selectorToStaticallyResolve|
				 aCCodeGenerator
					staticallyResolveMethodNamed: selectorToStaticallyResolve
					forClass: self
					to: (self staticallyResolvePolymorphicSelector: selectorToStaticallyResolve)]]]
]

{ #category : 'translation' }
SpurCompactor class >> implicitReturnTypeFor: aSelector [
	"Answer the return type for methods that don't have an explicit return."
	^#void
]

{ #category : 'api' }
SpurCompactor >> biasForGC [
	self subclassResponsibility
]

{ #category : 'api' }
SpurCompactor >> biasForSnapshot [
	self subclassResponsibility
]

{ #category : 'initialization' }
SpurCompactor >> coInterpreter: aVMSimulator [
	<doNotGenerate>
	coInterpreter := aVMSimulator
]

{ #category : 'api' }
SpurCompactor >> compact [
	self subclassResponsibility
]

{ #category : 'initialization' }
SpurCompactor >> manager: aSpurNBitMMXEndianSimulator [
	<doNotGenerate>
	manager := aSpurNBitMMXEndianSimulator.
	aSpurNBitMMXEndianSimulator coInterpreter ifNotNil:
		[:coint| coInterpreter := coint].
	aSpurNBitMMXEndianSimulator scavenger ifNotNil:
		[:scav| scavenger := scav]
]

{ #category : 'api' }
SpurCompactor >> postSwizzleAction [
	"do nothing"
]

{ #category : 'debugging' }
SpurCompactor >> printTheBogons: aBogon [
	<inline: true>
	coInterpreter
		print: 'bogon '; printHexnp: aBogon; cr
]

{ #category : 'api' }
SpurCompactor >> remapObj: objOop [
	<api>
	<inline: false>
	^manager vanillaRemapObj: objOop
]

{ #category : 'initialization' }
SpurCompactor >> scavenger: aSpurGenerationScavenger [
	<doNotGenerate>
	scavenger := aSpurGenerationScavenger
]

{ #category : 'api' }
SpurCompactor >> shouldRemapObj: objOop [
	<api>
	"Answer if the obj should be scavenged (or simply followed). The method is called
	 shouldRemapObj: for compatibility with ObjectMemory.  Defer to the compactor
	 to choose the actual test, there being a difference between the vanilla test and
	 that used with a sliding compactor where objects are not marked as forwarded."
	^manager vanillaShouldRemapObj: objOop
]
