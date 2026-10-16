# ScreenInk agent guide

ScreenInk is a macOS 26 menu-bar app. ⌃⌥R starts a recording of the display under the mouse, the microphone, and mouse clicks. ⌃⌥R again stops it and writes a folder in `~/ScreenInk/<timestamp>/` containing `report.md` (transcript split at each click, with before/after screenshots), then copies the report path to the clipboard.

## Layout

| Path | Contents |
|------|----------|
| `Sources/ScreenInkCore/` | Pure logic: models (`Session`, `Click`, `Segment`, `Display`), coordinate math, frame timing, markdown. No AppKit, no I/O. All unit tests target this. |
| `Sources/ScreenInk/main.swift` | App delegate, menu bar item, Carbon hotkey, `--package` CLI mode. |
| `Sources/ScreenInk/Recorder.swift` | ScreenCaptureKit video (`SCRecordingOutput`), `AVAudioRecorder` audio, global click monitor. Writes `session.json`. |
| `Sources/ScreenInk/Packager.swift` | Reads a recording folder, extracts screenshots (`AVAssetImageGenerator`), transcribes (`SpeechAnalyzer`), writes `report.md`. |
| `Tests/ScreenInkCoreTests/` | Swift Testing unit tests. |
| `scripts/e2e.sh` | Packages a synthetic recording (`say` audio, `ffmpeg` test video) and checks the output. |

Pipeline: `Recorder` produces `session.json` + `video.mov` + `audio.m4a`; `Packager.run(dir:)` turns that folder into the report. Times in `session.json` are seconds since audio start; `videoOffset` maps them onto the video.

## Commands

- `make check`: lint, build, unit tests, e2e. Must pass before a change is done.
- `make format`: auto-fix formatting and fixable lint issues.
- `make app` / `make run`: build `build/ScreenInk.app` (ad-hoc signed) and launch it.
- `.build/debug/ScreenInk --package <dir>`: rerun packaging on an existing recording folder without recording. Use this to iterate on report output.

Recording itself needs Screen Recording and Microphone permission and a human at the keyboard, so agents cannot exercise `Recorder` directly. Put testable logic in `ScreenInkCore`, and cover packaging changes with `scripts/e2e.sh`.

## Conventions

- Swift 6 language mode, strict concurrency. UI and recording state are `@MainActor`; framework delegate callbacks are `nonisolated` and hop to the main actor.
- Formatting is owned by `swift format` (`.swift-format`); `swiftlint` (`.swiftlint.yml`) covers the rest. Don't hand-format against them.
- Naming: Swift API Design Guidelines. Types `UpperCamelCase`, everything else `lowerCamelCase`, one primary type per file, file named after it.
- No force unwraps. Errors shown to the user are `ScreenInkError` with a message saying what to do.
- No new dependencies without a strong reason. Apple frameworks cover capture, speech, and imaging.
- Prefer the smallest change. Mark deliberate shortcuts with a `ponytail:` comment naming the limit and the upgrade path.
- Comments describe current behavior and why; no change history.
- New logic in `ScreenInkCore` gets a test in `Tests/ScreenInkCoreTests/`.

## Output contract

`report.md` is what users hand to other agents, so treat its format as an interface: relative image paths, `**Click N**` markers, and the files listed in its header. Update `scripts/e2e.sh` and `markdownSplitsTranscriptAtClicks` when it changes.
