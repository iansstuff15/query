#!/usr/bin/env bash
# Regenerates the README screenshots in docs/screenshots.
#   scripts/capture-screenshots.sh
# Runs ReadmeScreenshotTests, which opens each screen (stub data) in a real window and writes its
# window number; this script photographs each window with `screencapture` (Terminal needs Screen
# Recording permission) and tells the test to move on.
set -euo pipefail
cd "$(dirname "$0")/.."
folder="$HOME/Library/Containers/by-ian.query/Data/tmp/readme-screenshots"
out="docs/screenshots"
mkdir -p "$out" "$folder"
rm -f "$folder"/*.window "$folder"/*.done

TEST_RUNNER_QUERY_SCREENSHOTS=1 xcodebuild test -project query.xcodeproj -scheme query -testPlan Unit \
  -destination 'platform=macOS' -only-testing:queryTests/ReadmeScreenshotTests -quiet "$@" &
tests=$!

while kill -0 "$tests" 2>/dev/null; do
  for marker in "$folder"/*.window; do
    [ -e "$marker" ] || continue
    name="$(basename "$marker" .window)"
    screencapture -o -x -l "$(cat "$marker")" "$out/$name.png"
    rm "$marker"
    touch "$folder/$name.done"
    echo "captured $out/$name.png"
  done
  sleep 0.2
done
wait "$tests"
