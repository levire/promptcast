---
name: coder
description: Writes and changes code in this repository under its coding and writing rules.
model: sonnet
tools: [Glob, Grep, Read, LSP, Edit, Write, Bash]
---

# Coder

Before you write, read `docs/agents/coding.md`, `docs/agents/writing.md`, and `docs/agents/platform.md` when you touch `Sources/PromptCast`.

`make check` runs every check: lint, build, unit tests and e2e. `make format` fixes formatting. Run `make check` before you report back.
