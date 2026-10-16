# ScreenInk

VoiceInk for screen recordings. Press **⌃⌥R**, talk through a bug while clicking around, press **⌃⌥R** again. ScreenInk writes `~/ScreenInk/<timestamp>/report.md` with your transcript split at each click, a screenshot just before every click (click position ringed) and one second after, plus the full video. The report path is copied to your clipboard; paste it to an agent.

Everything runs on device: ScreenCaptureKit for video, Apple's `SpeechAnalyzer` for transcription.

## Requirements

macOS 26, Xcode 26, `swiftlint` and `ffmpeg` (`brew install swiftlint ffmpeg`, only for linting and the e2e test).

## Run

```sh
make run
```

On first use macOS asks for Microphone and Screen Recording access. After granting Screen Recording, quit (menu bar ◎ > Quit) and `make run` again. The app is ad-hoc signed, so permissions are requested again after each rebuild.

Change the shortcut and the transcription language in ◎ > Settings…. The shortcut can be a key combination or a single modifier key tapped alone (e.g. Left ⌘), which needs Input Monitoring permission. You can also stop a recording by clicking the overlay pill.

## Develop

```sh
git config core.hooksPath .githooks   # lint + tests on commit
make check                            # lint, build, tests, e2e
```

See [AGENTS.md](AGENTS.md) for layout and conventions.
