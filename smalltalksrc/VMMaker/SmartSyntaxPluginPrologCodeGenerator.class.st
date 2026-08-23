Class {
	#name : 'SmartSyntaxPluginPrologCodeGenerator',
	#superclass : 'Object',
	#category : 'VMMaker-SmartSyntaxPlugins',
	#package : 'VMMaker',
	#tag : 'SmartSyntaxPlugins'
}

{ #category : 'utilities' }
SmartSyntaxPluginPrologCodeGenerator >> stackAccessorFor: index [
	self assert: index isInteger.
	^'(interpreterProxy stackValue: ', (index printString, ')')
]
