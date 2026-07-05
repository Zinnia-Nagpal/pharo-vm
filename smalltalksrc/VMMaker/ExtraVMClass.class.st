Class {
	#name : 'ExtraVMClass',
	#superclass : 'VMClass',
	#category : 'VMMaker',
	#package : 'VMMaker'
}

{ #category : 'as yet unclassified' }
ExtraVMClass class >> sourceFileName [ ^ #extra.c
]

{ #category : 'accessing - structure variables' }
ExtraVMClass >> f [ <api> ^2
]
