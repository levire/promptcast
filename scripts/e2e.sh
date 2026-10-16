#!/bin/sh
# Packages a synthetic recording (generated speech + test video + two clicks) and checks the report.
set -eu
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
say -o "$dir/audio.m4a" --file-format=m4af --data-format=aac "First I open the settings page. Then I click save, and nothing happens."
ffmpeg -loglevel error -f lavfi -i testsrc=size=1000x500:rate=30:duration=6 -c:v libx264 -pix_fmt yuv420p "$dir/video.mov"
cat > "$dir/session.json" <<JSON
{"startedAt":"2026-01-01T00:00:00Z","videoOffset":0.1,"display":{"x":0,"y":0,"width":500,"height":250,"scale":2},
 "clicks":[{"time":2.2,"x":100,"y":200,"button":"left"},{"time":3.6,"x":400,"y":50,"button":"left"}]}
JSON
"${1:-.build/debug/PromptCast}" --package "$dir" >/dev/null
for f in report.md transcript.json start.png end.png clicks/001-before.png clicks/002-after.png; do
  test -s "$dir/$f" || { echo "missing $f"; exit 1; }
done
for marker in '![start](start.png)' '**Click 1**' '**Click 2**' '![end](end.png)'; do
  grep -qF "$marker" "$dir/report.md" || { echo "report.md lacks $marker"; exit 1; }
done
# Every image the report links to must exist.
grep -o '](\([^)]*\.png\))' "$dir/report.md" | sed 's/^](//; s/)$//' | while read -r img; do
  test -s "$dir/$img" || { echo "report.md links missing $img"; exit 1; }
done
grep -q '"text"' "$dir/transcript.json" || { echo "transcript.json has no segments"; exit 1; }
grep -qi 'settings' "$dir/report.md" || { echo "transcript missing"; cat "$dir/report.md"; exit 1; }
echo "e2e ok"
