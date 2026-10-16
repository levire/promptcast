# Platform layer

Rules for code that touches AppKit, SwiftUI and the system frameworks.

- UI and recording state are `@MainActor`. Framework callbacks that arrive on other queues are `nonisolated` and hop with `Task { @MainActor in }`; callbacks documented to run on the main thread use `MainActor.assumeIsolated`.
- Log with the shared `log` (subsystem `dev.promptcast`). Mark strings `privacy: .public` only when they hold no user content. Logs are the only way to debug a recording an agent cannot run: read them with `/usr/bin/log show --predicate 'subsystem == "dev.promptcast"' --last 10m` (the full path matters, because zsh has a `log` builtin).
- Permissions: macOS applies a new Screen Recording or Input Monitoring grant only after the app relaunches. Check access before using a capability, and tell the user to quit and reopen when it is missing.
- Permission grants are tied to the code signature. `make app` signs with the Apple Development identity so grants survive rebuilds; an ad-hoc build loses them on every rebuild.
- A new privacy-protected API needs its usage string in `Resources/Info.plist`, or the app crashes on first use.
- PromptCast's own windows are excluded from capture. A new window must not appear in recordings.
