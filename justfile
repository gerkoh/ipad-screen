server := "build/iPadScreen.app/Contents/MacOS/ipad-screen-mcp"

default:
    @just --list

# Build build/iPadScreen.app (the MCP server)
build:
    ./scripts/build.sh

# Run the unit tests
test:
    swift test

# Send the server the same tools/call Claude does and open the image it returns.
# Run from a terminal, this uses the terminal's Screen Recording permission.
capture: build
    #!/usr/bin/env bash
    set -euo pipefail
    out="$(mktemp -d)/ipad.jpg"
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"view_ipad_screen"}}' \
        | "{{server}}" \
        | /usr/bin/python3 -c 'import base64, json, sys
    item = json.loads(sys.stdin.readline())["result"]["content"][0]
    if item["type"] != "image": sys.exit(item["text"])
    open(sys.argv[1], "wb").write(base64.b64decode(item["data"]))' "$out"
    open "$out"

# Build build/iPadScreen.mcpb and open it in Claude Desktop to install or update it
extension: build
    ./scripts/package-extension.sh
    open build/iPadScreen.mcpb

# Link skills/ipad-explain into Claude Code's skills folder (/ipad-explain)
install-skill:
    #!/usr/bin/env bash
    set -euo pipefail
    target="$HOME/.claude/skills/ipad-explain"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "error: $target exists and isn't a link; move it aside first" >&2; exit 1
    fi
    mkdir -p "$HOME/.claude/skills"
    ln -sfn "{{justfile_directory()}}/skills/ipad-explain" "$target"
    echo "Linked $target"

# Zip the skill for Claude Desktop: Settings › Skills › upload build/ipad-explain.zip
skill-zip:
    @mkdir -p build
    @rm -f build/ipad-explain.zip
    @cd skills && zip -rq ../build/ipad-explain.zip ipad-explain -x '*.DS_Store'
    @echo "build/ipad-explain.zip"

clean:
    rm -rf .build build
