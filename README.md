# iPadScreen

Lets Claude Desktop see your iPad screen. QuickTime Player mirrors the iPad to the Mac;
a local MCP server gives Claude one tool, `view_ipad_screen`, that snapshots that
QuickTime window. Ask "check my working" in Claude and it looks at the page you're on.

Everything runs on this Mac. Nothing listens on the network, nothing is written to
disk, and the only place the image goes is the Claude conversation you asked in.

## Setup

```bash
just test        # unit tests
just extension   # build iPadScreen.mcpb and open it in Claude Desktop
```

Then:

1. Click **Install** in Claude's dialog. It appears as **iPad Screen** under
   Settings › Extensions.
2. Open QuickTime Player › File › New Movie Recording, click the ⌄ next to the record
   button and pick your iPad. You don't need to record.
3. Ask Claude something about your iPad. The first time, macOS asks to let **iPadScreen**
   record the screen: allow it in System Settings › Privacy & Security › Screen & System
   Audio Recording, then switch the extension off and on.

### Turning it on and off

Settings › Extensions › **iPad Screen** has a switch. On starts the server; off stops
it, so nothing of it runs and Claude can't call the tool. Leave it off when you're not
studying and flip it on when you are; no restart needed.

## The `/ipad-explain` skill

`skills/ipad-explain/SKILL.md` turns Claude into a tutor for what's on your page: it
looks at the iPad first, works out what you're stuck on, and explains step by step using
your own notation, giving hints before full answers.

- **Claude Code:** `just install-skill` links it into `~/.claude/skills`, so edits here
  take effect straight away. Type `/ipad-explain`.
- **Claude Desktop:** `just skill-zip`, then upload `build/ipad-explain.zip` under
  Settings › Skills. Re-upload after editing.

## How it works

`iPadScreen.app` is a background-only app whose executable is the MCP server; the
`.mcpb` is a zip of it plus `Resources/manifest.json`. While the extension is on, Claude
runs it and talks to it over stdin/stdout (JSON-RPC); it exits as soon as Claude closes
that pipe. While idle it waits on stdin: about 5 MB of memory and no CPU, no timers, no
network.

On each `view_ipad_screen` call it uses ScreenCaptureKit to capture the largest visible
QuickTime Player window, even when other windows cover it, scaled to at most 1568 px on
the long edge (Claude's useful limit), and returns it as a JPEG in the reply. A capture
takes about 60 ms (the first after start about 200 ms) and is roughly 210 KB.

If QuickTime isn't showing the iPad, or shows only black (iPad locked, asleep or
unplugged), the tool returns a short message saying so instead of a picture, and Claude
passes it on. The server keeps running; the next call works once the iPad is back.

## Security

- **One permission: Screen Recording**, which macOS requires to read another app's
  window. No camera, microphone, accessibility, network or file access is used.
- **Held by iPadScreen alone.** Claude Desktop launches MCP servers as their own
  responsible process, so they never borrow Claude's permissions; iPadScreen needs its
  own grant, and it only ever captures the QuickTime window.
- **Signed ad hoc, deliberately.** macOS pins the grant to this exact build, so a
  modified binary never inherits it. The cost is allowing it again after each rebuild.
- **Hardened Runtime** is on (the build fails without it), so no library can be
  injected into the process holding the grant.
- **What it can't stop:** any program already running as you could start the server and
  ask for a snapshot of the QuickTime window, as with any app you grant this permission
  to. It can't see anything else on screen.

## Things to know

- **QuickTime's record controls** appear over the picture while the pointer is on the
  window; move the pointer off it to keep them out of the snapshot.
- **One QuickTime window** at a time is the intended setup; with several, the largest
  visible one is used. A minimised window can't be captured.
- **macOS may re-confirm** the Screen Recording grant every so often; that's the system.
- `just capture` runs one capture from the terminal and opens it. Run that way it uses
  the terminal's Screen Recording permission, not iPadScreen's.

## Layout

| Path | What |
|---|---|
| `Sources/iPadScreenCore` | MCP protocol, window choice, sizing, black-frame check, messages |
| `Sources/ipad-screen-mcp` | The server: stdio loop and the ScreenCaptureKit capture |
| `Tests/iPadScreenCoreTests` | Unit tests for the core |
| `scripts/build.sh` | Builds and signs `build/iPadScreen.app` |
| `scripts/package-extension.sh` | Packs it into `build/iPadScreen.mcpb` |
| `Resources/manifest.json` | The Claude Desktop Extension manifest |
| `skills/ipad-explain` | The tutoring skill (`/ipad-explain`) |

## Licence

[MIT](LICENSE)
