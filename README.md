# PromptCast

VoiceInk for screen recordings. Press your shortcut (default **⌃⌥R**), talk through a bug while clicking around, and press it again or click the overlay pill. PromptCast writes `~/PromptCast/<timestamp>/report.md`: your transcript split at each click, a screenshot just before every click (click position ringed) and one second after, start and end screenshots, and the full video. The report path is copied to your clipboard; paste it to an agent.

Everything runs on device: ScreenCaptureKit for video, Apple's `SpeechAnalyzer` for transcription.

## Run

Requires macOS 26 and Xcode 26. For development also `brew install swiftlint ffmpeg`.

```sh
make run
```

macOS asks for Microphone and Screen Recording access on first use. After granting Screen Recording, quit PromptCast from the ◎ menu and open it again.

Set the shortcut and transcription language in ◎ > Settings…. A single modifier tapped alone (for example Left ⌘) works too and needs Input Monitoring permission.

## Develop

See [AGENTS.md](AGENTS.md). It applies to humans as well.
