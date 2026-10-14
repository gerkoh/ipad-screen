#!/usr/bin/env bash
# Registers build/ipad-screen-mcp with Claude Desktop. Idempotent; backs the config up
# first and leaves every other setting untouched.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
server="$root/build/ipad-screen-mcp"
config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

[ -x "$server" ] || { echo "error: $server missing; run 'just build' first" >&2; exit 1; }
mkdir -p "$(dirname "$config")"
[ -f "$config" ] && cp "$config" "$config.bak-$(date +%Y%m%d-%H%M%S)"

/usr/bin/python3 - "$config" "$server" <<'PY'
import json, os, sys
config, server = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(config):
    with open(config) as f:
        data = json.load(f)
data.setdefault("mcpServers", {})["ipad-screen"] = {"command": server, "args": []}
tmp = config + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, config)
PY

echo "Registered ipad-screen -> $server"
echo "Quit Claude Desktop completely (Cmd+Q) and reopen it to load the server."
