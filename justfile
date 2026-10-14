default:
    @just --list

# Build the MCP server and the capture app into build/
build:
    ./scripts/build.sh

# Run the unit tests
test:
    swift test

# Capture the QuickTime window once, the same way Claude does, and open the result
capture: build
    #!/usr/bin/env bash
    set -euo pipefail
    out="$(mktemp -d)/ipad.jpg"
    open -n -g -W build/iPadScreenCapture.app --args --out "$out"
    if [ -s "$out" ]; then open "$out"; else cat "$out.error"; echo; exit 1; fi

# Create the local signing identity that keeps Screen Recording across rebuilds (once)
signing-identity:
    ./scripts/create-signing-identity.sh

# Build, then register the MCP server with Claude Desktop (backs up its config first)
install-claude: build
    ./scripts/install-claude.sh

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
    mkdir -p build
    rm -f build/ipad-explain.zip
    cd skills && zip -rq ../build/ipad-explain.zip ipad-explain -x '*.DS_Store'
    @echo "build/ipad-explain.zip"

clean:
    rm -rf .build build
