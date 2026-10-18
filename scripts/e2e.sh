#!/bin/sh
# Packages a synthetic recording (generated speech + test video + two clicks) and checks the report.
set -eu
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
say -o "$dir/audio.m4a" --file-format=m4af --data-format=aac "First I open the settings page. Then I click save, and nothing happens."
# A gray screen, so only the click ring is red, with a patch at the bottom left that brightens with time, so the
# brightness tells frames apart. The video is 1.5 times the display's pixel size, so the ring must be scaled.
ffmpeg -loglevel error -f lavfi \
  -i "color=c=gray:s=1500x750:r=30:d=6 [bg]; color=s=300x150:r=30:d=6,format=gray,geq=lum='T*40' [fg]; [bg][fg] overlay=0:600" \
  -c:v libx264 -pix_fmt yuv420p "$dir/video.mov"
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

# Prints the RGB values of one pixel, in top-left-origin coordinates.
pixel() { ffmpeg -loglevel error -i "$1" -vf "crop=1:1:$2:$3" -f rawvideo -pix_fmt rgb24 - | od -An -tu1; }
# Prints the brightness of the patch, which grows with the time of the frame.
brightness() { pixel "$1" 150 675 | awk '{ print $2 }'; }
is_red() { pixel "$@" | awk '{ exit !($1 > 200 && $2 < 80 && $3 < 80) }'; }
# Click 1 at display point (100, 200) is video pixel (300, 150), and the ring radius is 66 pixels.
is_red "$dir/clicks/001-before.png" 366 150 || { echo "click 1 has no ring at its position"; exit 1; }
# Click 2 at display point (400, 50) is video pixel (1200, 600).
is_red "$dir/clicks/002-before.png" 1266 600 || { echo "click 2 has no ring at its position"; exit 1; }
is_red "$dir/clicks/001-after.png" 366 150 && { echo "the after screenshot has a ring"; exit 1; }
# Expected frame times: start 0 s, click 1 before 1.95 s and after 3.1 s, end 5.95 s.
levels="$(brightness "$dir/start.png") $(brightness "$dir/clicks/001-before.png") $(brightness "$dir/clicks/001-after.png")"
echo "$levels $(brightness "$dir/end.png")" | awk '{ exit !($1 + 10 < $2 && $2 + 10 < $3 && $3 + 10 < $4) }' ||
  { echo "screenshots are not in time order (start, click 1 before, after, end): $levels"; exit 1; }
# GitHub's macOS runners cannot download speech models, so CI sets PROMPTCAST_E2E_SKIP_TRANSCRIPT=1.
if [ "${PROMPTCAST_E2E_SKIP_TRANSCRIPT:-0}" != 1 ]; then
  grep -qi 'settings' "$dir/report.md" || { echo "transcript missing"; cat "$dir/report.md"; exit 1; }
fi
echo "e2e ok"
