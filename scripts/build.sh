#!/usr/bin/env bash
# Builds build/ipad-screen-mcp and build/iPadScreenCapture.app side by side (the MCP
# server finds the app next to itself) and signs both.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build"
app="$out/iPadScreenCapture.app"
local_identity="iPadScreen Local Code Signing"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    identity="$CODESIGN_IDENTITY"
elif security find-certificate -c "$local_identity" >/dev/null 2>&1; then
    identity="$local_identity"
else
    # Ad hoc works, but each build is a new app to macOS and loses Screen Recording.
    echo "note: no '$local_identity' (just signing-identity); signing ad hoc" >&2
    identity="-"
fi

swift build --package-path "$root" -c release
bin="$(swift build --package-path "$root" -c release --show-bin-path)"

rm -rf "$app" "$out/ipad-screen-mcp"
mkdir -p "$app/Contents/MacOS"
cp "$bin/iPadScreenCapture" "$app/Contents/MacOS/iPadScreenCapture"
cp "$root/Resources/iPadScreenCapture-Info.plist" "$app/Contents/Info.plist"
cp "$bin/ipad-screen-mcp" "$out/ipad-screen-mcp"

codesign --force --options runtime --sign "$identity" "$app"
codesign --force --options runtime --sign "$identity" "$out/ipad-screen-mcp"
codesign --verify --strict "$app"
codesign --verify --strict "$out/ipad-screen-mcp"

echo "$out/ipad-screen-mcp"
