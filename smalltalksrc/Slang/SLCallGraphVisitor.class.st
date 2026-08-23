Class {
	#name : 'SLCallGraphVisitor',
	#superclass : 'Object',
	#instVars : [
		'codeGenerator',
		'alreadyVisited'
	],
	#category : 'Slang-Optimizations',
	#package : 'Slang',
	#tag : 'Optimizations'
}

{ #category : 'instance creation' }
SLCallGraphVisitor class >> codeGenerator: aCodeGenerator [
	
	^ self new
		codeGenerator: aCodeGenerator;
		yourself
]

{ #category : 'accessing' }
SLCallGraphVisitor >> codeGenerator [

	^ codeGenerator
]

{ #category : 'accessing' }
SLCallGraphVisitor >> codeGenerator: anObject [

	codeGenerator := anObject
]

{ #category : 'initialization' }
SLCallGraphVisitor >> initialize [

	super initialize.
	alreadyVisited := Set new.
]

{ #category : 'private' }
SLCallGraphVisitor >> internalVisitMethod: aTMethod [

	"Recursive private method. Called only once per selector/method in the callgraph visit"

	| shouldVisitMethod calledSelectors |
	(alreadyVisited includes: aTMethod) ifTrue: [ ^ self ].
	alreadyVisited add: aTMethod.

	shouldVisitMethod := self preVisitMethod: aTMethod.
	shouldVisitMethod ifFalse: [ ^ self ].

	calledSelectors := (aTMethod externalCallsIn: codeGenerator)
		collect: [ :e | e selector ] as: Set.
	calledSelectors do: [ :aSelector |
			self internalVisitSelector: aSelector ].
	
	self postVisitMethod: aTMethod.
]

{ #category : 'private' }
SLCallGraphVisitor >> internalVisitSelector: aSelector [

	"Recursive private method. Called only once per selector/method in the callgraph visit"

	| method |
	method := codeGenerator methodNamed: aSelector.

	"The method could be nil if not found in the list of methods to translate.
		This could be because the selector is either
		 - a special selector (+, /, perform: ...)
		 - a C selector (str:cpy:_:_:)
		 - or a selector that was inlined and removed by some other pass..."
	method ifNotNil: [ self internalVisitMethod: method ]
]

{ #category : 'hooks' }
SLCallGraphVisitor >> postVisitMethod: aTMethod [
	
	^ true
]

{ #category : 'hooks' }
SLCallGraphVisitor >> preVisitMethod: aTMethod [
	
	^ true
]

{ #category : 'api' }
SLCallGraphVisitor >> startFromSelector: aSelector [
	
	"Non-recursive public method. Called only once per callgraph visit"
	^ self internalVisitSelector: aSelector
]
