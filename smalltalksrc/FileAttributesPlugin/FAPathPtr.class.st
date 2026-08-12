Class {
	#name : 'FAPathPtr',
	#superclass : 'VMStructType',
	#instVars : [
		'sessionId',
		'faPath',
		'plugin'
	],
	#category : 'FileAttributesPlugin',
	#package : 'FileAttributesPlugin'
}

{ #category : 'instance creation' }
FAPathPtr class >> fromArray: anArray plugin: aFileAttributesPluginSimulator [

	^self new
		sessionId: anArray first;
		faPath: anArray second;
		plugin: aFileAttributesPluginSimulator;
		yourself
]

{ #category : 'translation' }
FAPathPtr class >> instVarNamesAndTypesForTranslationDo: aBinaryBlock [
	"Define a CallbackContext, the argument to sendInvokeCallbackContext:
	 self typedef"

	self instVarNames do:
		[:ivn|
		aBinaryBlock
			value: ivn
			value: (ivn caseOf: {
						['sessionId']				-> [#'int'].
						['faPath']			-> [#'fapath *']}
						otherwise: [#'void *'])]
]

{ #category : 'instance creation' }
FAPathPtr class >> plugin: aFileAttributesPlugin [

	^self new 
		plugin: aFileAttributesPlugin;
		yourself
]

{ #category : 'accessing' }
FAPathPtr >> faPath [

	^ faPath
]

{ #category : 'accessing' }
FAPathPtr >> faPath: anObject [

	^ faPath := anObject.
]

{ #category : 'accessing' }
FAPathPtr >> plugin [

	^ plugin
]

{ #category : 'accessing' }
FAPathPtr >> plugin: anObject [

	^ plugin := anObject.
]

{ #category : 'accessing' }
FAPathPtr >> sessionId [

	^ sessionId
]

{ #category : 'accessing' }
FAPathPtr >> sessionId: anObject [

	^ sessionId := anObject.
]
