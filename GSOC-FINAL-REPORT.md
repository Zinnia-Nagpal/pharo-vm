# GSoC 2026 Final Report: Enhance Slang with Separate Compilation

**Student:** Zinnia Nagpal

**Mentor:** Nahuel Palumbo

**Organization:** Pharo

**Project:** Enhance Slang with Separate Compilation

---

## Project Summary

The Pharo VM is written in Slang, a subset of Smalltalk that is transpiled to C
by the `CCodeGenerator`. Before this project, the entire VM was generated into
a handful of large monolithic C files `cointerp.c` alone exceeds 94,000
lines  making the codebase difficult to navigate, maintain, and incrementally
recompile.

This project set out to introduce **separate compilation** to Slang:
refactoring `CCodeGenerator` to route generated C code into multiple files,
one per class hierarchy, while correctly tracking and emitting `#include`
dependencies between them. The work completed during the program is a
validated, working proof of concept for this pattern, along with
documentation of the mechanics involved and what remains for a full
implementation.

---

## What Was Completed

### 1. Fixed Failing Test Suite (Merged)

Before starting the main project work, I fixed 36 failing tests in
`MLLocalizationTestCase`, and moved it from `Melchor` into the `VMMakerTests`
package so it runs in CI.

**Branch:** [`fix-ml-localization-tests`](https://github.com/Zinnia-Nagpal/pharo-vm/commits/fix-ml-localization-tests) — merged into `pharo-12`.

Key commits:
- `02d64323b` — Fix failing MLLocalizationTestCase tests
- `08c7549a1` — Move MLLocalizationTestCase to VMMakerTests and fix setUp

### 2. Separate Compilation Proof of Concept

The main GSoC work implements and validates the full separate compilation
pipeline, using a small, deliberately minimal ancillary class (`ExtraVMClass`)
to isolate and understand the translation mechanics involved.

**Branch:** [`extra-file`](https://github.com/Zinnia-Nagpal/pharo-vm/tree/extra-file)

#### a) Created `ExtraVMClass` — a class that generates its own C file

```smalltalk
Class {
	#name : 'ExtraVMClass',
	#superclass : 'VMClass',
	#category : 'VMMaker-Core',
	#package : 'VMMaker',
	#tag : 'Core'
}

ExtraVMClass class >> sourceFileName [
	^ 'extra.c'
]

ExtraVMClass class >> apiExportHeaderName [
	^ 'extra.h'
]

ExtraVMClass >> f [
	<api>
	^ 42
]
```

Two details here turned out to matter a great deal (see "Challenges" below):
the method must be **instance-side**, and it must carry the **`<api>`**
pragma, or Slang's dead-code elimination silently drops it from the
generated output with no error at all.

#### b) Added `generateExtraFile` to `VMMaker`

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

This is called as part of the standard `generateMainVM` pipeline, alongside
`generateInterpreterFile` and `generateCogitFiles`:

```smalltalk
VMMaker >> generateMainVM [
	self
		generateInterpreterFile;
		generateCogitFiles;
		generateExtraFile;
		generateInternalPlugins;
		...
]
```

#### c) Generated `extra.h` with the correct function prototype

`storeAPIExportHeader:OnFile:` produces `extra.h` containing:
```c
extern sqInt f(void);
```

#### d) Made `cointerp.c` aware of `extra.h`

`CoInterpreter class >> declareCVarsIn:` was extended with an explicit header
include, alongside the VM's other headers:

```smalltalk
aCCodeGenerator
	addHeaderFile: '"cointerp.h"';
	addHeaderFile: '"extra.h"';
	addHeaderFile: '"cogit.h"'.
```## Key Links

- Fork: <https://github.com/Zinnia-Nagpal/pharo-vm>
- Separate compilation proof of concept (full history): <https://github.com/Zinnia-Nagpal/pharo-vm/tree/extra-file>
- Documentation: <https://github.com/Zinnia-Nagpal/pharo-vm/blob/extra-file/doc/how-to-generate-extra-c-file.md>
- 36-test-fix branch (merged): <https://github.com/Zinnia-Nagpal/pharo-vm/commits/fix-ml-localization-tests>

**Key commits on `extra-file`** (for a quicker path through the history than
scrolling the full branch):
- [`fce71e873`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/fce71e873) — Initial `ExtraVMClass` and `extra.c` file created
- [`fc780d8cf`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/fc780d8cf) — Added `extra.c` to the cmake build
- [`774b09332`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/774b09332) — Generated `extra.h` and includes
- [`62f899c5f`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/62f899c5f) — Added `ExtraVMClass` to `ancilliaryClasses` (later found to be wrong — see Challenges)
- [`4fe76d901`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/4fe76d901) — Removed instance-side `f` to fix a duplicate C symbol
- [`cab3daaf9`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/cab3daaf9) — Final working approach: call `f()` directly, no `new`, no class-side method
- [`37ff92da4`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/37ff92da4) — Final correction: removed `ExtraVMClass` from `ancilliaryClasses`
- [`34088f284`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/34088f284) — Added tests

Earlier draft attempts at this same proof of concept exist on
`separate-compilation`, `separate-compilation-v2`, and
`separate-compilation-clean`; `extra-file` is the final, consolidated,
working version and is the one referenced throughout this report.

Without this, the compiler fails with `implicit declaration of function 'f'`
even though `extra.h` correctly declares it — nothing was including it.

#### e) Added `extra.c` to the cmake build

`extra.c` was added to the CMake build alongside `cointerp.c` so it compiles
and links as part of the normal VM build.

#### f) Called `f()` from `primitiveAdd`

```smalltalk
InterpreterPrimitives >> primitiveAdd [
	self cCode: 'printf("f() returned %ld\n", (long)f())'.
	self pop2AndPushIntegerIfOK: (self stackIntegerValue: 1) + (self stackIntegerValue: 0)
]
```

`f()` is called as a plain global C function — no receiver, no `new`.

#### g) Verified end-to-end at runtime

The built VM was run against a test image with `eval "1+1"`, confirmed
independently by my mentor on his own machine:

```
$ ./buildDirectory/build/vm/pharo --headless <image> eval "1+1"
f() returned 42
f() returned 42
... (repeated once per primitiveAdd invocation during startup/eval)
2
```

This confirms code generated into `cointerp.c` correctly calls a function
defined and compiled in the separately-generated `extra.c`.

---

### 3. Tests

Added to `SlangBasicTranslationTest`:

- `testExtraFileIsGenerated` — confirms `extra.c` is produced by
  `generateExtraFile`.
- `testExtraFileContainsFFunction` — confirms the generated file actually
  contains `f`'s definition.
- `testAncilliaryClassesDoesNotIncludeExtraVMClass` — regression test for a
  bug found during development (see below): if `ExtraVMClass` is listed in
  `CoInterpreter class >> ancilliaryClasses`, `f` gets translated twice —
  once into its own file, once (duplicated) into the main interpreter file —
  causing a `multiple definition of 'f'` linker error.

All three pass and call `generateExtraFile` directly rather than doing a
full VM generation, which also avoids an unrelated pre-existing bug
described below.

Two further tests were attempted but not completed — see "What's Left."

---

## Current State

| Goal | Status |
|---|---|
| Generate `extra.c` from a Pharo class | Working |
| Generate `extra.h` with function prototype | Working |
| `#include "extra.h"` in `cointerp.c` | Working (manual `addHeaderFile:`) |
| `extra.c` added to cmake build | Working |
| Call function from `extra.c` in the interpreter | Working |
| Verified at runtime | Working (confirmed by mentor) |
| Core tests (generation-only) | 3 passing |
| Tests requiring full VM generation | Blocked (see below) |

---

## What's Left

1. **Two tests could not be completed.**
   `testFNotDuplicatedInMainInterpreterFile` and
   `testMainFileIncludesExtraHeader` need to inspect the generated *main*
   interpreter file, which requires a full VM generation. That currently
   hits an unrelated, pre-existing bug:
   `TranslationError: Undefined local or argument header type declaration`,
   thrown from `SpurImageReader>>SIR_doLoadImageFromFile:withHeader:`. It
   reproduces identically via both `PharoVMMaker generate: #CoInterpreter`
   and the narrower `VMMaker >> generateInterpreterFile`, so it is not
   specific to this project's changes and is worth investigating separately.

2. **Automated dependency tracking is not implemented.** This proof of
   concept shows the pieces Slang already has (`sourceFileName`,
   `apiExportHeaderName`, `<api>`, `addHeaderFile:`) can support per-file
   output, but every wiring step is currently manual. In particular:
   - `addHeaderFile:` has to be added by hand to every file that needs to
     reference another file's output.
   - Whether a class should go into `ancilliaryClasses` or get its own
     dedicated file (via a `generate<Name>File` method) is a manual,
     easy-to-get-wrong decision — choosing wrong produces a linker error
     (`multiple definition`) rather than a clear diagnostic.

   A full implementation would derive these `#include` dependencies
   automatically, based on which types/variables/functions each file's
   methods actually reference.

3. **No real subsystem has been extracted yet.** The next concrete step per
   the original project proposal — extracting `SpurMemoryManager` (the GC)
   into its own file using this pattern — was not attempted within the
   program timeline.

---

## What Got Merged Upstream

- The `MLLocalizationTestCase` fixes (36 tests) were merged into the main
  `pharo-vm` repository via `pharo-12`.
- The `ExtraVMClass` proof of concept and its documentation are **not**
  intended to be merged upstream as-is. `ExtraVMClass` is a deliberately
  artificial, minimal example built to isolate and understand the
  translation mechanics — not real VM functionality. Its value is the
  documented pattern and findings below, intended to inform a properly
  scoped future implementation of separate compilation.

---

## How to Reproduce

```bash
# Clone the fork
git clone https://github.com/Zinnia-Nagpal/pharo-vm.git
cd pharo-vm
git checkout extra-file

# Build (from an existing configured buildDirectory, on WSL/Linux)
cmake -S . -B buildDirectory -DPHARO_DEPENDENCIES_PREFER_DOWNLOAD_BINARIES=TRUE
cmake --build buildDirectory --target install

# Run the tests (from inside a Pharo image loaded with this VMMaker package)
# In a Playground:
#   (SlangBasicTranslationTest selector: #testExtraFileIsGenerated) run.
#   (SlangBasicTranslationTest selector: #testExtraFileContainsFFunction) run.
#   (SlangBasicTranslationTest selector: #testAncilliaryClassesDoesNotIncludeExtraVMClass) run.
```

A full VM run against a test image (`eval "1+1"`, confirmed to print
`f() returned 42` and then `2`) was verified separately by my mentor on his
own machine; exact image and build-directory setup will vary depending on
how `buildDirectory` was originally configured.

---

## Documentation

A full write-up of the working pattern — including every wrong turn taken,
why each one failed, and how to verify the generated output — is at:

[`doc/how-to-generate-extra-c-file.md`](https://github.com/Zinnia-Nagpal/pharo-vm/blob/extra-file/doc/how-to-generate-extra-c-file.md)

---

## Challenges and What I Learned

- **The gap between "compiles" and "generates correct C" is easy to miss.**
  Several of the mistakes made along the way — a duplicate C symbol, a
  silently empty `extra.c` — produced no Smalltalk-level error at all. The
  mistake only surfaced as a C compiler/linker failure, or as a completely
  silent omission with no error whatsoever. This reinforced my mentor's
  advice to check the actual generated C output at every step, not just
  whether the Smalltalk side compiles cleanly.
- **Several plausible approaches to calling a function in a separately
  generated file turned out to be wrong, each for a different reason:**
  - `ExtraVMClass new f` doesn't translate — Slang doesn't support `new` for
    ancillary classes.
  - A class-side method, called via `ExtraVMClass f`, works right up until
    the class is *also* listed in `ancilliaryClasses` — then it's translated
    twice, causing a duplicate-symbol linker error.
  - Even after fixing that, a class-side method with no `<api>` pragma got
    silently eliminated as unreachable dead code.
  - The eventual, correct approach — an instance-side method with `<api>`,
    **not** listed in `ancilliaryClasses`, called directly as a global C
    function — was the simplest of everything tried.
- **Git/Iceberg workflow across two environments (a Windows Pharo image and
  a WSL build) needs discipline.** Work was lost more than once from
  hand-editing generated `.st` files directly in a text editor to resolve
  merge conflicts or route around a temporarily corrupted image state — a
  text editor doesn't understand Smalltalk method boundaries, and a
  slightly-off edit can silently splice two methods together. The safer
  pattern was to always edit through Pharo's compiler (which validates
  syntax immediately) and commit/push right after any change, rather than
  leaving image-only edits in an uncommitted, unsynced state.

---

## Key Links

- Fork: <https://github.com/Zinnia-Nagpal/pharo-vm>
- Separate compilation proof of concept (full history): <https://github.com/Zinnia-Nagpal/pharo-vm/tree/extra-file>
- Documentation: <https://github.com/Zinnia-Nagpal/pharo-vm/blob/extra-file/doc/how-to-generate-extra-c-file.md>
- 36-test-fix branch (merged): <https://github.com/Zinnia-Nagpal/pharo-vm/commits/fix-ml-localization-tests>

**Key commits on `extra-file`** (for a quicker path through the history than
scrolling the full branch):
- [`fce71e873`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/fce71e873) — Initial `ExtraVMClass` and `extra.c` file created
- [`fc780d8cf`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/fc780d8cf) — Added `extra.c` to the cmake build
- [`774b09332`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/774b09332) — Generated `extra.h` and includes
- [`62f899c5f`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/62f899c5f) — Added `ExtraVMClass` to `ancilliaryClasses` (later found to be wrong — see Challenges)
- [`4fe76d901`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/4fe76d901) — Removed instance-side `f` to fix a duplicate C symbol
- [`cab3daaf9`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/cab3daaf9) — Final working approach: call `f()` directly, no `new`, no class-side method
- [`37ff92da4`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/37ff92da4) — Final correction: removed `ExtraVMClass` from `ancilliaryClasses`
- [`34088f284`](https://github.com/Zinnia-Nagpal/pharo-vm/commit/34088f284) — Added tests

Earlier draft attempts at this same proof of concept exist on
`separate-compilation`, `separate-compilation-v2`, and
`separate-compilation-clean`; `extra-file` is the final, consolidated,
working version and is the one referenced throughout this report.
