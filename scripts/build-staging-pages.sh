#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

copy_file(){
  local path="$1"
  test -f "$ROOT/$path"
  mkdir -p "$DIST/$(dirname "$path")"
  cp "$ROOT/$path" "$DIST/$path"
}

copy_file index.html
copy_file sw.js
copy_file manifest-v9.webmanifest
copy_file robots.txt
copy_file _headers

for path in   app-icon-safe.svg   apple-music.svg   apple-touch-icon.png   favicon-32.png   favicon.ico   favicon.svg   icon-192.png   icon-512.png   launch-logo-white.svg   social-preview-v176.jpg   social-preview-v180.jpg   spotify.svg   youtube-music.svg
do
  copy_file "$path"
done

cp -R "$ROOT/ios-launch" "$DIST/ios-launch"
cp -R "$ROOT/notifications" "$DIST/notifications"

# Never publish development/server-only notification backend source into staging.
rm -rf   "$DIST/notifications/worker"   "$DIST/notifications/tests"   "$DIST/notifications/scripts"   "$DIST/notifications/core"
rm -f   "$DIST/notifications/backend-contract.md"   "$DIST/notifications/README.md"   "$DIST/notifications/notification-contract.schema.json"

test -f "$DIST/index.html"
test -f "$DIST/sw.js"
test -f "$DIST/_headers"
test -f "$DIST/notifications/client.js"
test -f "$DIST/notifications/config.json"

echo "Prepared IPCDJ Worship staging assets in $DIST"
