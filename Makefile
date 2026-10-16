APP := build/ScreenInk.app

.PHONY: build test e2e lint format check app run clean

build:
	swift build

test:
	swift test

e2e: build
	scripts/e2e.sh

lint:
	swift format lint --strict --recursive Sources Tests Package.swift
	swiftlint lint --strict --quiet

format:
	swift format --in-place --recursive Sources Tests Package.swift
	swiftlint lint --fix --quiet

# Everything an agent must pass before calling a change done.
check: lint build test e2e

# Signs with the first Apple Development identity so macOS keeps granted permissions across rebuilds; ad-hoc otherwise.
SIGN_ID ?= $(shell security find-identity -p codesigning -v | awk '/Apple Development/ {print $$2; exit}')

app:
	swift build -c release
	rm -rf $(APP) && mkdir -p $(APP)/Contents/MacOS
	cp .build/release/ScreenInk $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign "$(or $(SIGN_ID),-)" $(APP)

run: app
	open $(APP)

clean:
	rm -rf .build build
