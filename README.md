# iPadScreen

Lets Claude Desktop see your iPad screen. QuickTime Player mirrors the iPad to the Mac;
a local MCP server gives Claude one tool, `view_ipad_screen`, that snapshots that
QuickTime window. Ask "check my working" in Claude and it looks at the page you're on.

Everything runs on this Mac. Nothing listens on the network, and the only place the
image goes is the Claude conversation you asked in.

## Setup

```bash
just test             # unit tests
just install-claude   # build, then register the server in Claude Desktop's config
```

Then:

1. Quit Claude Desktop completely (⌘Q) and reopen it. `ipad-screen` appears under
   Settings › Developer.
2. Open QuickTime Player › File › New Movie Recording, click the ⌄ next to the record
   button and pick your iPad. You don't need to record.
3. Ask Claude something about your iPad. The first time, macOS asks to allow
   **iPadScreenCapture** to record the screen: allow it in System Settings › Privacy &
   Security › Screen & System Audio Recording, then ask again.

`just capture` takes one snapshot the same way Claude does and opens it, which is
handy for checking the setup without Claude.

## The `/ipad-explain` skill

`skills/ipad-explain/SKILL.md` turns Claude into a tutor for what's on your page: it
looks at the iPad first, works out what you're stuck on, and explains step by step using
your own notation, giving hints before full answers.

- **Claude Code:** `just install-skill` links it into `~/.claude/skills`, so edits here
  take effect straight away. Type `/ipad-explain`.
- **Claude Desktop:** `just skill-zip`, then upload `build/ipad-explain.zip` under
  Settings › Skills. Re-upload after editing.

## How it works

```
Claude Desktop ──stdio──▶ build/ipad-screen-mcp ──open──▶ build/iPadScreenCapture.app
                                   ▲                          │ ScreenCaptureKit:
                                   └──── JPEG in $TMPDIR ◀────┘ QuickTime window only
```

- `ipad-screen-mcp` speaks MCP (JSON-RPC over stdin/stdout) and has no permissions.
- `iPadScreenCapture.app` runs once per request, captures the largest on-screen
  QuickTime Player window (even if other windows cover it), writes a JPEG of at most
  1568 px on the long edge (Claude's useful limit), and exits. The server reads and
  deletes it straight away.

### Why a separate capture app

macOS gives a process launched by Claude the same Screen Recording access as Claude
itself. Granting it to Claude would let every MCP server and extension Claude starts
record your whole screen. Launching the capture app through `open` makes it its own
app in macOS's eyes, so only it holds the grant, and it only ever captures QuickTime.

## Things to know

- **Keep the permission across rebuilds** by running `just signing-identity` once. It
  adds a self-signed "iPadScreen Local Code Signing" certificate to your login keychain
  (usable only by `codesign`), and `just build` signs with it from then on. Without it
  builds are signed ad hoc, which macOS treats as a new app each time. The first build
  after switching needs Screen Recording allowed once more; after that it sticks.
- **macOS may re-confirm** the Screen Recording grant every so often; that's the system,
  not this app.
- **QuickTime's record controls** appear over the picture while the pointer is on the
  window; move the pointer off it to keep them out of the snapshot.
- **One QuickTime window** at a time is the intended setup; with several, the largest
  visible one is used.

## Layout

| Path | What |
|---|---|
| `Sources/iPadScreenCore` | Pure logic: MCP protocol, window choice, sizing, handoff |
| `Sources/ipad-screen-mcp` | The stdio server Claude runs |
| `Sources/iPadScreenCapture` | The capture app (ScreenCaptureKit) |
| `Tests/iPadScreenCoreTests` | Unit tests for the core |
| `skills/ipad-explain` | The tutoring skill (`/ipad-explain`) |
| `scripts/build.sh` | Builds and signs both into `build/` |
| `scripts/install-claude.sh` | Adds the server to Claude Desktop's config (with a backup) |
