# Coding

This file sets the shape of code. `docs/agents/writing.md` sets the words, in comments and docstrings too. `docs/agents/platform.md` adds the rules for code that touches the system frameworks.

## A layer meets another through an interface

`PromptCastCore` holds every decision that can be made without the system: models, timing, coordinate math, report text. It imports only Foundation, and a lint rule enforces this. `PromptCast` is the thin layer over AppKit, SwiftUI and the capture, speech and input frameworks.

When platform code needs a calculation or a decision, put it in Core as a pure function and test it there. Platform code that decides something can be checked only by a person who makes a recording.

A recording flows one way: the recorder writes raw files and `session.json`, and the packager turns that folder into the report. Keep that split, so that packaging can run again from a folder on disk.

## A package exports its surface and keeps the rest

In Core, `public` marks the surface that the app uses. Everything else stays internal. A function that only forwards a call to another function adds nothing. Publish the function that does the work.

## Make it impossible before making it detectable

If a type can make a mistake impossible, use the type instead of a test that catches the mistake. Keep the cases of a thing in an enum. A runtime guard for a case that the type rules out reads as a case that can happen. Delete it.

Swift 6 language mode with strict concurrency is on. Do not silence the compiler with `@unchecked Sendable` or `nonisolated(unsafe)`; a lint rule rejects both. Do not use force unwraps, force casts or `try!`.

## Break a guard once to see that it holds

A lint rule, a check or a test that never failed is not shown to work. For a lint rule or a check, add the violation that it must catch in a separate file, see it fail, and delete that file. For a test, break the code that it protects: flip a comparison, remove a branch, skip an assignment. See the test fail, then restore the code. If no plausible change turns a test red, delete the test.

## Test at the lowest layer that can catch it

Test a defect once, at the cheapest layer that catches it. A rule in Core gets a Swift Testing test in `Tests/PromptCastCoreTests/`. `scripts/e2e.sh` covers what only a full packaging run shows: files on disk and the links between them. Do not test that Apple's frameworks do their job.

## A test checks what a caller can observe

A test calls its subject as a caller does, and checks what the caller can observe: the return value, or what it can read back after the call. One test covers one behavior. A test that breaks when a rewrite keeps every behavior tests the implementation. Name a test after the behavior it covers, and say the expectation in the failure message.

## A test protects something that can break

A test is worth its place when a mistake that a person can plausibly make turns it red: a rule, a boundary, a value that must match a system constant, a bug that happened before. Do not test that a property returns what the initializer stored, or that a constant equals the literal in its own declaration.

Take the expected value from a source that is independent of the code: a literal that you work out by hand, the specification, or a system constant. A test that computes its expectation with the code under test, or repeats its formula, passes by construction. Write `trigger.press(at: 1.0) == .cancel`, not `trigger.press(at: CancelTrigger.maxInterval) == .cancel`.

## Name a thing for what is in it

One type per file, and the file has the name of the type. Private helpers that only that type uses can share its file.

Give a declaration the name that an experienced Swift developer who never saw this repository would give, following the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). A function that returns a value and changes nothing gets the name of what it returns. A function that changes something gets a verb. Do not use vague names: `handle`, `process`, `manage`, `data`, `utils`, `helpers`. A name that reads well but says something the body does not do is worse than an awkward accurate name. One thing gets one word everywhere.

## A docstring says what the declaration does

A docstring states the contract in one to three sentences: what the declaration does or returns, and when it fails. It does not say how the body works or why the code has this shape. Those go in the pull request. A `public` declaration in Core always has a docstring. An internal declaration has none if its name and signature already say what it does.

## Settings, errors and dependencies

- Every persisted setting goes through `Preferences`, so that each key is spelled once.
- An error that the user sees is a `PromptCastError`, and its message says what to do next.
- Add no package dependency without asking the user. Apple frameworks cover capture, speech and imaging.

## The report is an interface

Other agents read `report.md`. Change its format deliberately, and update the report tests and `scripts/e2e.sh` in the same change.

## Prefer the smallest change

Write the least code that does the job. Mark a deliberate shortcut with a `ponytail:` comment that names its limit and the upgrade path.
