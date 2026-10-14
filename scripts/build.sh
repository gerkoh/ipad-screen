#!/usr/bin/env bash
# Builds build/iPadScreen.app, whose main executable is the MCP server Claude runs.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/iPadScreen.app"

swift build --package-path "$root" -c release
bin="$(swift build --package-path "$root" -c release --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin/ipad-screen-mcp" "$app/Contents/MacOS/ipad-screen-mcp"
cp "$root/Resources/iPadScreen-Info.plist" "$app/Contents/Info.plist"
# manifest.json is the one place the version lives; Claude only installs an update
# whose version is higher than the installed one.
version="$(/usr/bin/plutil -extract version raw "$root/Resources/manifest.json")"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$version" "$app/Contents/Info.plist"

# Ad hoc: macOS pins the Screen Recording grant to this exact build, so a modified
# binary never inherits it (the cost: allow it again after each rebuild).
# Hardened Runtime: blocks DYLD_INSERT_LIBRARIES and unsigned libraries, so nothing can
# be injected into the process that holds the grant.
codesign --force --options runtime --sign - "$app"
codesign --verify --strict "$app"
signature="$(codesign --display --verbose "$app" 2>&1)"
grep -Eq 'flags=0x[0-9a-f]+\([^)]*runtime' <<<"$signature" \
    || { echo "error: Hardened Runtime missing from $app" >&2; exit 1; }

echo "$app/Contents/MacOS/ipad-screen-mcp"
