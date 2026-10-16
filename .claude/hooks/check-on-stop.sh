#!/bin/sh
# Stop: block finishing while make check fails, unless sources are unchanged or Claude is already retrying.
input=$(cat)
[ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ] && exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0
git status --porcelain -- Sources Tests scripts Package.swift .swiftlint.yml .swift-format | grep -q . || exit 0
out=$(make check 2>&1) || { echo "make check failed:" >&2; echo "$out" | tail -40 >&2; exit 2; }
exit 0
