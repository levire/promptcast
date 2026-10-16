# PromptCast

macOS menu-bar app: a global shortcut records the screen, microphone and mouse clicks, then writes `~/PromptCast/<timestamp>/report.md` (transcript split at each click, with screenshots) for handing to an agent.

## Rules

`docs/agents/` holds every rule for the repository, one file per topic. Read the ones your change touches before you write.

| File | Covers |
| --- | --- |
| `coding.md` | how code is shaped: layers, types, tests, names, docstrings |
| `platform.md` | code that touches AppKit, SwiftUI and the system frameworks |
| `writing.md` | prose, in comments, docs, issues and pull requests |
| `commits.md` | the commit message convention |

## Commands

- `make check`: lint (swift-format, SwiftLint, Periphery, gitleaks), build, unit tests, e2e. Run it before calling any change done. CI and the git hooks run the same checks.
- `make format`: fix formatting and auto-fixable lint issues.
- `.build/debug/PromptCast --package <dir>`: rebuild the report of an existing recording folder, to iterate on output without recording.
- `make run`: build and launch `build/PromptCast.app`.

Agents cannot record: capture needs Screen Recording, Microphone and Input Monitoring permission and a person at the keyboard. Verify through `make check`, and ask the user to try a recording when a change touches capture.

## Agents and workflows

`.claude/agents/` holds the agent definitions. Each says what its agent knows, not when it runs. `.claude/workflows/implement.js` combines them into plan, challenge, build, review and verify. `/implement` runs it.
