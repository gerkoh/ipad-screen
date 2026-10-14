#!/usr/bin/env bash
# Packs build/iPadScreen.app into build/iPadScreen.mcpb, a Claude Desktop Extension.
# Installed, it gets an on/off switch in Claude › Settings › Extensions that starts and
# stops the server.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/iPadScreen.app"
stage="$root/build/extension"
bundle="$root/build/iPadScreen.mcpb"

[ -d "$app" ] || { echo "error: $app missing; run 'just build' first" >&2; exit 1; }

manifest_version="$(/usr/bin/plutil -extract version raw "$root/Resources/manifest.json")"
app_version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")"
[ "$manifest_version" = "$app_version" ] \
    || { echo "error: manifest $manifest_version != app $app_version" >&2; exit 1; }

rm -rf "$stage" "$bundle"
mkdir -p "$stage/server"
cp "$root/Resources/manifest.json" "$stage/manifest.json"
# ditto keeps the executable bit and the code signature intact.
ditto "$app" "$stage/server/iPadScreen.app"
codesign --verify --strict "$stage/server/iPadScreen.app"

(cd "$stage" && zip -qry "$bundle" manifest.json server)
rm -rf "$stage"
echo "$bundle"
