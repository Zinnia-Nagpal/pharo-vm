Class {
	#name : 'VMStackBuilder',
	#superclass : 'VMAbstractBuilder',
	#instVars : [
		'page',
		'frames',
		'args',
		'methodBuilder'
	],
	#category : 'VMMakerTests-Builders',
	#package : 'VMMakerTests',
	#tag : 'Builders'
}

{ #category : 'frames' }
VMStackBuilder >> addFrame: aFrame [
	frames add: aFrame
]

{ #category : 'frames' }
VMStackBuilder >> addNewFrame [
	| frame |
	"'add' a new frame in the sense of an OrderedCollection, which will be iterated with #do:
	The last frame added, will be the stackTop"
	frame := VMFrameBuilder new initializeWithInterpreter: interpreter andMemory: memory andMethodBuilder: methodBuilder.
	frames add: frame.
	^ frame "the frame is then configured by the caller"
]

{ #category : 'accessing' }
VMStackBuilder >> args [
	^ args
]

{ #category : 'accessing' }
VMStackBuilder >> args: anObject [
	args := anObject
]

{ #category : 'build' }
VMStackBuilder >> buildStack [
	self createStackPage.
	self preparePage.
	self pushFrames.
	self setInterpreterVariables.
	^ frames last
]

{ #category : 'stack' }
VMStackBuilder >> createStackPage [
	| sp |
	frames ifEmpty:[ self error ].

	page := interpreter stackPages newStackPage.
	"set base stackPointer"
	sp := page baseAddress + memory wordSize.
	interpreter stackPointer: sp.
]

{ #category : 'accessing' }
VMStackBuilder >> frames [
	^ frames
]

{ #category : 'accessing' }
VMStackBuilder >> frames: anObject [
	frames := anObject
]

{ #category : 'initialization' }
VMStackBuilder >> initialize [
	super initialize.
	frames := OrderedCollection new. "will be treated in reverse"
	args := OrderedCollection new.
	
	"used to reset"
	page := nil.
]

{ #category : 'accessing' }
VMStackBuilder >> lastFrame [
	
	^ frames last
]

{ #category : 'accessing' }
VMStackBuilder >> methodBuilder [

	^ methodBuilder
]

{ #category : 'accessing' }
VMStackBuilder >> methodBuilder: anObject [

	methodBuilder := anObject
]

{ #category : 'accessing' }
VMStackBuilder >> page [
	^ page
]

{ #category : 'accessing' }
VMStackBuilder >> page: anObject [
	page := anObject
]

{ #category : 'build' }
VMStackBuilder >> preparePage [
	"Page setup before the base frame"
	interpreter push: memory nilObject.	"receiver"
	self pushArgs. "arguments"
	interpreter push: memory nilObject.  "senderContext"
	interpreter push: 0. "savedFp"
	page baseFP: interpreter stackPointer.

]

{ #category : 'build' }
VMStackBuilder >> pushAllButFirstFrames [
	2 to: frames size do: [ :anIndex | | aFrame |
			aFrame := frames at: anIndex.
			
			aFrame previousFrameArgsSize: ((frames at: anIndex - 1) argumentSize).
			
			interpreter push: interpreter framePointer.	
				
			self pushFrame: aFrame.
			aFrame callerFrame: (frames at: anIndex - 1)."for better inspection"
			]
]

{ #category : 'initialization' }
VMStackBuilder >> pushArgs [
	args do: [ :anArg | interpreter push: anArg ]
]

{ #category : 'build' }
VMStackBuilder >> pushBaseFrame [
	frames first previousFrameArgsSize: args size.
	self pushFrame: frames first.

]

{ #category : 'build' }
VMStackBuilder >> pushFrame: aFrame [
	
	interpreter framePointer: interpreter stackPointer.
	page headFP: interpreter stackPointer.

	aFrame pushYourself.
	page headSP: interpreter stackPointer.
]

{ #category : 'build' }
VMStackBuilder >> pushFrames [
	self pushBaseFrame.
	self pushAllButFirstFrames.
]

{ #category : 'as yet unclassified' }
VMStackBuilder >> reset [
	self initialize.
]

{ #category : 'build' }
VMStackBuilder >> setInterpreterVariables [
	| lastFrame |
	interpreter setStackPageAndLimit: page.
	interpreter setStackPointersFromPage: page.
	
	lastFrame := frames last.

	interpreter method: lastFrame method.
	
	interpreter initExtensions.
	

]

{ #category : 'accessing' }
VMStackBuilder >> topFrame [
	^ frames last
]
