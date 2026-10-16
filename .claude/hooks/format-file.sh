#!/bin/sh
# PostToolUse: format the edited Swift file and report remaining lint errors back to Claude.
file=$(jq -r '.tool_input.file_path // empty')
case "$file" in *.swift) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
swift format --in-place "$file"
out=$(swiftlint lint --quiet --strict "$file" 2>&1) || { echo "$out" >&2; exit 2; }
exit 0
