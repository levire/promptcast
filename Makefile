APP := build/PromptCast.app

.PHONY: build test e2e lint format check mutate app run clean

# Every target depends on build, so the committed hooks activate on first use without a setup step.
build:
	@git config core.hooksPath .githooks 2>/dev/null || true
	swift build

test: build
	swift test

e2e: build
	scripts/e2e.sh

lint: build
	swift format lint --strict --recursive Sources Tests Package.swift
	swiftlint lint --strict --quiet
	periphery scan --strict --quiet
	gitleaks git --no-banner --redact --log-level warn

format:
	swift format --in-place --recursive Sources Tests Package.swift
	swiftlint lint --fix --quiet

# Everything an agent must pass before calling a change done.
check: lint build test e2e

# Mutation testing of Core with Muter (brew install muter-mutation-testing/formulae/muter). Not part of check.
mutate: build
	muter run --skip-update-check --skip-coverage --format plain \
		$(addprefix --files-to-mutate ,$(wildcard Sources/PromptCastCore/*.swift))

# Signs with the first Apple Development identity so macOS keeps granted permissions across rebuilds; ad-hoc otherwise.
SIGN_ID ?= $(shell security find-identity -p codesigning -v | awk '/Apple Development/ {print $$2; exit}')

app:
	swift build -c release
	rm -rf $(APP) && mkdir -p $(APP)/Contents/MacOS
	cp .build/release/PromptCast $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign "$(or $(SIGN_ID),-)" $(APP)

run: app
	open $(APP)

clean:
	rm -rf .build build
