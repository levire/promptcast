# ScreenInk

macOS menu-bar app: a global shortcut records the screen, microphone and mouse clicks, then writes `~/ScreenInk/<timestamp>/report.md` (transcript split at each click, with screenshots) for handing to an agent.

## Commands

- `make check`: lint, build, unit tests, e2e. Run it before calling any change done; CI and the pre-commit hook run the same target.
- `make format`: fix formatting and auto-fixable lint issues.
- `.build/debug/ScreenInk --package <dir>`: rebuild the report of an existing recording folder. Use it to iterate on output without recording.
- `make run`: build and launch `build/ScreenInk.app`. Only a human can use it; see below.

Agents cannot record: capture needs Screen Recording, Microphone and Input Monitoring permission and a person at the keyboard. Verify through `make check`, and ask the user to try a recording when a change touches capture.

## Architecture

- `ScreenInkCore` holds every decision that can be made without the system: models, timing, coordinate math, report text. It imports only Foundation (a lint rule enforces this) and is where unit tests go.
- `ScreenInk` is the thin layer over AppKit, SwiftUI and the capture, speech and input frameworks. Keep logic out of it: when platform code needs a calculation or a decision, put that in Core as a pure function and test it there. `Sources/ScreenInk/AGENTS.md` has the rules for this layer.
- A recording flows one way: the recorder writes raw files and `session.json`, then the packager turns that folder into the report. Keep that split so packaging stays reproducible from a folder on disk.

## Rules

- Swift 6 language mode with strict concurrency. Never silence the compiler with `@unchecked Sendable` or `nonisolated(unsafe)`.
- No force unwraps, force casts or `try!`.
- One type per file, named after the type. Private helpers used only by that type may share its file.
- Errors the user sees are `ScreenInkError` and say what to do next.
- Every persisted setting goes through `Preferences`, so each key is spelled once.
- No package dependencies without asking the user. Apple frameworks cover capture, speech and imaging.
- New logic in Core comes with a Swift Testing test.
- `report.md` is read by other agents, so its format is an interface. Change it deliberately and update the report tests and `scripts/e2e.sh` with it.
- Prefer the smallest change. Mark a deliberate shortcut with a `ponytail:` comment naming its limit and the upgrade path.
- Comments state what the code does now and why. No history, no ticket numbers.
- Commit messages: imperative summary line under 72 characters, body explaining why.
