Class {
	#name : 'UUIDPlugin',
	#superclass : 'SmartSyntaxInterpreterPlugin',
	#category : 'VMMaker-Plugins',
	#package : 'VMMaker',
	#tag : 'Plugins'
}

{ #category : 'translation' }
UUIDPlugin class >> hasHeaderFile [
	"If there is a single intrinsic header file to be associated with the plugin, here is where you want to flag"
	^true
]

{ #category : 'translation' }
UUIDPlugin class >> requiresPlatformFiles [
	"this plugin requires platform specific files in order to work"
	^true
]

{ #category : 'system primitives' }
UUIDPlugin >> MakeUUID: location [

	<doNotGenerate>
	self notYetImplemented
]

{ #category : 'initialize' }
UUIDPlugin >> initialiseModule [
	<export: true>
	^self cCode: 'sqUUIDInit()' inSmalltalk:[true]
]

{ #category : 'system primitives' }
UUIDPlugin >> primitiveMakeUUID [
    "This generates an UUID inside the 16 bytes long ByteArray to which it is sent."
	| oop location |
	<export: true>
	<var: #location type: #'char*'>
	oop := interpreterProxy stackValue: 0.
	(interpreterProxy methodArgumentCount = 0
	 and: [(interpreterProxy isBytes: oop)
	 and: [(interpreterProxy byteSizeOf: oop) = 16]]) ifFalse:
		[^interpreterProxy primitiveFail].
	location := interpreterProxy firstIndexableField: oop.
	self cCode: [self MakeUUID: location]
		inSmalltalk:
			[| uuid |
			uuid := UUID new.
			1 to: 16 do:
				[:i| location at: i - 1 put: (uuid at: i)]].
	^oop
]

{ #category : 'initialize' }
UUIDPlugin >> shutdownModule [
	<export: true>
	^self cCode: 'sqUUIDShutdown()' inSmalltalk:[true]
]
