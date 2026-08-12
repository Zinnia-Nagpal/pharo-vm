Class {
	#name : 'SLAutomaticLocalization',
	#superclass : 'Object',
	#instVars : [
		'codeGenerator',
		'selector',
		'callgraphVariableCollector'
	],
	#category : 'Slang-Optimizations',
	#package : 'Slang',
	#tag : 'Optimizations'
}

{ #category : 'applying' }
SLAutomaticLocalization >> applyMethodNamed: interpreterSelector [ 

	| autolocalizedVariables |
	autolocalizedVariables := codeGenerator
		initAutoLocalizationOfVariablesIn: interpreterSelector.
	self
		autoLocalizationOfVariablesIn: interpreterSelector
		withVariableBindings: autolocalizedVariables
]

{ #category : 'applying' }
SLAutomaticLocalization >> autoLocalizationOfVariablesIn: aSelector withVariableBindings: replacementList [

	| m replacementDict |
	(m := codeGenerator methodNamed: aSelector) ifNil: [ ^ self ].
	(replacementList isNil or: [ replacementList isEmpty ]) ifTrue: [ ^ self ].

	codeGenerator currentMethod: m.

	replacementDict := (replacementList collect: [ :asso | 
				 asso key -> (TVariableNode named: asso value) ]) asDictionary.
	"Replace all localized variables by their localized versions"
	m parseTree
		bindVariablesIn: replacementDict.

	self linearizeExternalCallsIn: m withVariableBindings: replacementDict.

	"Wrap sends with externalization/internalization statements"
	self wrapStatements: m withVariableBindings: replacementDict.

	"Localize global values at the beginning of the function
	AND externalize local values on each return"
	replacementDict associationsDo: [ :asso | 
		m statements addFirst: (TAssignmentNode
				 variable: asso value copy
				 expression: (TVariableNode named: asso key)) ].
]

{ #category : 'accessing' }
SLAutomaticLocalization >> codeGenerator [

	^ codeGenerator
]

{ #category : 'accessing' }
SLAutomaticLocalization >> codeGenerator: anObject [

	codeGenerator := anObject.
	callgraphVariableCollector := SLCallGraphFreeVariableCollector codeGenerator: codeGenerator
]

{ #category : 'applying' }
SLAutomaticLocalization >> externalizationOf: aVariableName [

	^ (TAssignmentNode
			variableNamed: aVariableName
			expression: (TVariableNode named: #local_, aVariableName))
]

{ #category : 'applying' }
SLAutomaticLocalization >> internalizationOf: aVariableName [

	^ (TAssignmentNode
			variableNamed: #local_, aVariableName
			expression: (TVariableNode named: aVariableName))
]

{ #category : 'applying' }
SLAutomaticLocalization >> linearizeExternalCallsIn: aTMethod withVariableBindings: replacementDict [

	"Should be applied after inlining.
	Linearize all calls inside this method"

	| lineariser linearStatementList |
	lineariser := SLLinearisationVisitor new
		codeGenerator: codeGenerator;
		localizedVariables: replacementDict keys;
		yourself.

	linearStatementList := aTMethod parseTree accept: lineariser.
	aTMethod parseTree: linearStatementList
]

{ #category : 'applying' }
SLAutomaticLocalization >> localizableVariablesInStatement: statement withVariableBindings: localizedVariables [

	"Optimization: only externalize/localize variables used by the statement's called functions"

	| collector |
	collector := SLLocalizableVariableCollector
		             inCodeGenerator: codeGenerator
		             localizableCandidateVariables: localizedVariables
		             callgraphVariableCollector: callgraphVariableCollector.
	^ (statement accept: collector) localizableVariables
]

{ #category : 'applying' }
SLAutomaticLocalization >> wrapStatementWithExternalizationAndLocalizations: statement ofLocalizedVariables: localizedVariables [

	| variablesToExternalize replacementStatements potentialCall |

	"Only non inlined sends, or message sends in assignments `tx := send` should be wrapped"
	potentialCall := statement isAssignment ifTrue: [ statement expression ] ifFalse: [ statement ].
	(potentialCall isReturn or: [
		(codeGenerator isFunctionCall: potentialCall)
			or: [ codeGenerator isDynamicCall: potentialCall ]])
				ifFalse: [ ^ statement ].
	
	"Optimization: only externalize/localize variables used by the statement's called functions"
	variablesToExternalize := (self
		localizableVariablesInStatement: statement
		withVariableBindings: localizedVariables) sorted.

	"Sorted to guarantee determinism in the output"
	variablesToExternalize ifEmpty: [ ^ statement ].

	"Wrap the statement with externalization/localizations"
	replacementStatements := OrderedCollection new.
	replacementStatements addAll: (variablesToExternalize collect: [ :e | self externalizationOf: e ]).
	replacementStatements add: statement.
	statement isReturn ifFalse: [ 
		replacementStatements addAll: (variablesToExternalize collect: [ :e | self internalizationOf: e ]) ].
	^ TStatementListNode statements: replacementStatements
]

{ #category : 'applying' }
SLAutomaticLocalization >> wrapStatements: tMethod withVariableBindings: replacementDict [

	"Wrap statements with external calls with TExternalSendNode"
	"Apply externalization/localization of variables around 
	 - static function calls
	 - dynamic function calls (perform & co)"
	tMethod allStatements do: [ :statement | | replacement oldParent |
		oldParent := statement parent.
		replacement := self
			wrapStatementWithExternalizationAndLocalizations: statement
			ofLocalizedVariables: replacementDict keys.
		oldParent replaceChild: statement with: replacement.
	].
]
