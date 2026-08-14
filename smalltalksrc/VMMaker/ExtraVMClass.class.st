Class {
	#name : 'ExtraVMClass',
	#superclass : 'VMClass',
	#category : 'VMMaker-Core',
	#package : 'VMMaker',
	#tag : 'Core'
}

{ #category : 'translation' }
ExtraVMClass class >> apiExportHeaderName [

	^ 'extra.h'
]

{ #category : 'accessing - structure variables' }
ExtraVMClass class >> f [
	^ 42
]

{ #category : 'translation' }
ExtraVMClass class >> sourceFileName [

	^ 'extra.c'
]