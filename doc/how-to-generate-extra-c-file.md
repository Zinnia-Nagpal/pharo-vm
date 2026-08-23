# How to Generate a Separate C File from Slang

This document explains, step by step, how to get Slang's `CCodeGenerator` to emit a
small, standalone C file (with its own header) from a dedicated Smalltalk class,
and how that file's functions can be called from the main interpreter file
(`gcc3x-cointerp.c`). It's based on a hands-on proof of concept built around a
minimal example class, `ExtraVMClass`, whose only job is to define one function,
`f()`, that returns `42`.

This is a **proof of concept for separate compilation in Slang** a step toward
splitting the monolithic, tens-of-thousands-of-lines interpreter file into smaller,
per-subsystem files (e.g. eventually `spurMemoryManager.c`, `cogit.c`, etc.).

## 1. Define the ancillary class

Create a plain `VMClass` subclass. This class does not need any instance variables
for this minimal example:

```smalltalk
Class {
	#name : 'ExtraVMClass',
	#superclass : 'VMClass',
	#category : 'VMMaker-Core',
	#package : 'VMMaker',
	#tag : 'Core'
}
```

## 2. Tell it which files to generate into

Two **class-side** methods tell the code generator what file names to use for this
class's C output and header:

```smalltalk
ExtraVMClass class >> sourceFileName [
	^ 'extra.c'
]

ExtraVMClass class >> apiExportHeaderName [
	^ 'extra.h'
]
```

## 3. Define the function as an instance-side method with `<api>`

This is the most important — and least obvious — part.

```smalltalk
ExtraVMClass >> f [
	<api>
	^ 42
]
```

Two things matter here:

- **It must be instance-side, not class-side.** Slang's ancillary-class handling
  expects instance-side methods for functions meant to be linked/called this way.
  (We initially tried a class-side `f`, which superficially seemed to work but
  caused problems described below.)
- **It needs the `<api>` pragma.** Without it, Slang's dead-code elimination
  determined that nothing in the traced call graph "used" `f`, and silently
  dropped it from the generated output — `extra.c` came out completely empty,
  with no error. The `<api>` pragma marks the method as an external entry point,
  forcing it to be kept regardless of whether Slang can trace a caller.

## 4. Add a generation method to `VMMaker`

```smalltalk
VMMaker >> generateExtraFile [
	| tmp1 |
	tmp1 := self createCogitCodeGenerator.
	tmp1
		vmClass: ExtraVMClass;
		addClass: ExtraVMClass;
		inferTypes;
		prepareMethods;
		storeCodeOnFile:
			(self sourceFilePathFor: ExtraVMClass sourceFileName)
		doInlining: self doInlining;
		storeAPIExportHeader: ExtraVMClass apiExportHeaderName
		OnFile: (self includeFilePathFor: ExtraVMClass apiExportHeaderName)
]
```

This builds a code generator scoped to just `ExtraVMClass`, infers types, prepares
methods, and writes both the `.c` and `.h` files. Calling `generateExtraFile` alone
(without doing a full `generate: #CoInterpreter`) is enough to produce `extra.c`
and `extra.h` — it does **not** require the whole VM to be generated, which is
useful for testing this in isolation (see "Testing" below).

## 5. Make the header visible to the main interpreter file

Having `extra.h` exist on disk isn't enough — the main interpreter file
(`gcc3x-cointerp.c`) needs an explicit `#include "extra.h"` to see `f`'s
declaration. Add this in `CoInterpreter class >> declareCVarsIn:`, alongside the
existing header includes:

```smalltalk
CoInterpreter class >> declareCVarsIn: aCCodeGenerator [
	...
	aCCodeGenerator
		addHeaderFile: '"cointerp.h"';
		addHeaderFile: '"extra.h"';
		addHeaderFile: '"cogit.h"'.
	...
]
```

Without this, the compiler fails with `implicit declaration of function 'f'`,
even though `extra.h` correctly declares it — the file just was never
`#include`d anywhere.

**This manual `addHeaderFile:` step is exactly the gap that automated
dependency tracking (a `#include`-emission mechanism based on actual
usage) is meant to eliminate.** Right now, whoever adds a new ancillary
file has to remember to wire up this include by hand.

## 6. Call the function from a primitive

```smalltalk
InterpreterPrimitives >> primitiveAdd [
	self cCode: 'printf("f() returned %ld\n", (long)f())'.
	self pop2AndPushIntegerIfOK: (self stackIntegerValue: 1) + (self stackIntegerValue: 0)
]
```

`f()` is a plain global C function — call it directly, with no receiver and no
`new`. This is the key insight after several wrong turns (see below).

## 7. What `ExtraVMClass` must NOT be in

**Do not add `ExtraVMClass` to `CoInterpreter class >> ancilliaryClasses`.**

It's tempting to think this is required — `ancilliaryClasses` is the standard
mechanism for telling the interpreter's code generator about extra classes it
should know about. But `ExtraVMClass` already gets its own, separate translation
pass via `generateExtraFile` (step 4). If it's *also* listed in
`ancilliaryClasses`, its methods get translated a second time, directly into the
main interpreter's compilation unit — producing a **second, duplicate
definition of `f`** and a linker error: `multiple definition of 'f'`.

The rule of thumb: a class either (a) gets its own dedicated file via a
`generate<Name>File`-style method plus `sourceFileName`/`apiExportHeaderName`, or
(b) gets folded into the main file via `ancilliaryClasses` — not both.

## Wrong turns (and why they failed)

These are documented because they're each individually plausible and easy to
try first — knowing why they fail should save the next person real time.

| Attempt | What happened | Why |
|---|---|---|
| `ExtraVMClass new f` | `implicit declaration of function 'new'; use of undeclared identifier '_ExtraVMClass'` | Slang doesn't support `new` on ancillary classes the way it does in normal Smalltalk — there's no C-level allocator/struct instantiation generated for them by default. `new` gets mistranslated. |
| `ExtraVMClass` added to `ancilliaryClasses`, `f` called via `ExtraVMClass f` (class-side) | Compiles and links... until `ExtraVMClass` is *also* separately generated via `generateExtraFile` — then `multiple definition of 'f'` at link time | Two independent translation passes (the ancillary-class pass and the dedicated-file pass) both emit a global C function for the same method. |
| Class-side `f`, no `ancilliaryClasses` entry | `extra.c` generated, but completely empty — no `f` function anywhere, no error | Slang's dead-code elimination didn't see any traceable caller of the class-side method and dropped it. This is what `<api>` is for. |
| Instance variable `extra` on the interpreter, set via `initialize`, then calling `extra f` | Would have worked in principle, but `initialize` methods are explicitly documented as **not translated to C** (`"#initialize methods do /not/ get translated"`) — so the instance never actually gets created at the C level | Not attempted to completion once this was noticed; abandoned once we confirmed `f()` can just be called directly as a global function instead. |

The final, working approach — instance-side `f` with `<api>`, not in
`ancilliaryClasses`, called as a plain global `f()` — is the simplest of
everything tried, and matches how `extra.c`/`extra.h` are meant to work as an
independent compilation unit.

## Verifying the generated output

After running `generateExtraFile`, check:

**`extra.c`** should contain exactly one definition:
```c
/* ExtraVMClass>>#f */
sqInt
f(void)
{
	return 42;
}
```

**`extra.h`** should declare it:
```c
extern sqInt f(void);
```

**`gcc3x-cointerp.c`** should:
- Include `#include "extra.h"` near its other header includes
- Contain exactly one call site (inside `primitiveAdd`), and **no** duplicate
  definition of `f` itself

A quick sanity check from the shell, after a full build:

```bash
grep -rn "^f(void)\|ExtraVMClass>>#f" generated/64/vm/src/*.c
```

should show `f`'s definition in `extra.c` only, nowhere else.

## Testing this without a full VM build

Doing a full `PharoVMMaker generate: #CoInterpreter` (or even the narrower
`generateInterpreterFile`) currently hits an unrelated, pre-existing bug in
`SpurImageReader` (`TranslationError: Undefined local or argument header type
declaration`, in `SIR_doLoadImageFromFile:withHeader:`). This is not related to
`ExtraVMClass` and reproduces the same way regardless of which full-generation
entry point is used.

Because of this, tests that only need the `extra.c` file (not the full
interpreter) should call `generateExtraFile` directly rather than a full
`generate:`:

```smalltalk
testExtraFileIsGenerated
	| outputDir maker |
	outputDir := FileLocator temp asFileReference / 'test-vm-gen'.
	outputDir ensureCreateDirectory.
	maker := PharoVMMaker on: CoInterpreter outputDirectory: outputDir fullName.
	maker generateExtraFile.
	self assert:
		(outputDir / 'generated' / '64' / 'vm' / 'src' / 'extra.c') exists.
	outputDir deleteAll.
```

Note the output path: `generateExtraFile` writes to
`<outputDirectory>/generated/64/vm/src/extra.c` (and the header to
`.../vm/include/extra.h`), not directly into `outputDirectory`.

Tests that need to check the *main* interpreter file (e.g. confirming
`#include "extra.h"` is present, or that `f` isn't duplicated there) currently
cannot run end-to-end until the `SpurImageReader` bug is fixed separately, since
they require full generation.

## Summary / next steps for full separate compilation

This proof of concept shows the pieces already exist in Slang to support
per-class output files:
- `sourceFileName` / `apiExportHeaderName` to route a class's output to its own
  file
- `<api>` to keep specific methods from being eliminated as unreachable
- `addHeaderFile:` to declare a cross-file dependency

What's still manual, and would need to become automatic for this to scale to
real subsystems (e.g. moving `SpurMemoryManager` to its own file):

1. **Dependency tracking** — right now, whoever creates a new separate file has
   to remember to add the right `addHeaderFile:` calls by hand in every file
   that references it. This should be derived automatically from which types,
   variables, and functions each file's methods actually reference.
2. **Choosing between `ancilliaryClasses` and a dedicated file** — this is
   currently a manual, easy-to-get-wrong decision (see the "wrong turns" table
   above). A real subsystem extraction should make this an explicit,
   documented choice per class hierarchy, not something you can silently do
   wrong and only discover via a linker error.
3. **The `SpurImageReader` bug** — blocks testing/using full generation
   end-to-end at all right now; worth investigating independently.
