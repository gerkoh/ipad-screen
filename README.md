# iPadScreen

Let Claude Desktop see your iPad screen. Write in GoodNotes (or anything else) on the
iPad, ask Claude "check my working", and it looks at the page you're on before it
answers.

It runs only on your Mac: nothing goes over the network, nothing is saved to disk, and
the picture only goes into the Claude chat you asked in.

## 1. Connect the iPad to the Mac (each session)

1. Plug the iPad into the Mac with a cable and unlock it. The first time, tap **Trust**
   on the iPad when it asks about this computer.
2. Open **QuickTime Player** and choose **File › New Movie Recording**.
   (Not *New Screen Recording*; that records the Mac's own screen.)
3. Click the **⌄** next to the red record button and pick your **iPad** under Camera.
   The QuickTime window now shows your iPad's screen.
4. Leave that window open. You don't need to press record. It can sit behind other
   windows, but don't minimise it.

## 2. Set up Claude (once)

You need macOS 14 or later, [Claude Desktop](https://claude.ai/download), Swift 6
(Xcode or the Command Line Tools) and [`just`](https://github.com/casey/just)
(`brew install just`).

1. In this folder, run:

   ```bash
   just extension
   ```

   This builds the extension and opens it in Claude Desktop. Click **Install**. It shows
   up as **iPad Screen** in Claude › Settings › Extensions.
2. Ask Claude anything about your iPad (see below). The first time, macOS asks to let
   **iPadScreen** record the screen. Allow it in **System Settings › Privacy &
   Security › Screen & System Audio Recording**, then in Claude go to Settings ›
   Extensions › iPad Screen and switch it off and on again.
3. Optional, the tutoring skill:
   - **Claude Desktop:** run `just skill-zip`, then upload `build/ipad-explain.zip` in
     Claude › Settings › Skills.
   - **Claude Code:** run `just install-skill`.

## 3. Use it

With the QuickTime window showing your iPad, ask Claude things like:

- "Look at my iPad. Is my working right?"
- "What's wrong with the step I just wrote?"
- "Explain the equation at the bottom of my page."
- `/ipad-explain` (with the skill installed): Claude reads your page, works out what
  you're stuck on and explains step by step, giving hints before full answers.

Claude takes a fresh look every time you ask, so keep writing and ask again.

**Turning it off:** Claude › Settings › Extensions › iPad Screen › **Configure** (or
**⋯**) has the switch. Off means the server isn't running and Claude can't look. It
also stops whenever Claude quits.

### If something's not right

| Claude says or shows | Fix |
|---|---|
| "No QuickTime Player window is showing the iPad" | Do step 1 again; the window can be covered but not minimised. |
| "The QuickTime window is showing only black" | Unlock the iPad, check the cable; if QuickTime lost it, re-pick the iPad under ⌄. |
| "iPadScreen doesn't have Screen Recording permission" | Allow it as in step 2.2, then switch the extension off and on. |
| QuickTime's record buttons cover part of the page | Move the pointer off the QuickTime window and ask again. |
| Claude doesn't use the tool at all | Check iPad Screen is on in Settings › Extensions, or say "look at my iPad". |

## Updating

After changing the code, bump `version` in `Resources/manifest.json` (the only place
it's set) and run `just extension` again, then accept Claude's update. Claude ignores a
package whose version isn't higher than the one installed. macOS will ask for Screen
Recording again, because every build counts as a new app (see Security).

## How it works

The extension is `iPadScreen.app`, a background-only app with no window or Dock icon,
whose program is a local [MCP](https://modelcontextprotocol.io) server. While the
extension is on, Claude runs it and talks to it through a pipe (stdin/stdout). It has
one read-only tool, `view_ipad_screen`.

Each time Claude calls the tool, the server takes a snapshot of the largest visible
QuickTime Player window with ScreenCaptureKit, even if other windows cover it. It
scales it to at most 1568 px on the long edge (larger only costs Claude more tokens)
and sends it back as a JPEG. A snapshot takes about 60 ms (about 200 ms for the first)
and is about 200 KB. If the picture is almost entirely black, it sends a message
instead of the image.

Between calls it just waits: no CPU, no timers, no network, about 20 MB of memory. It
exits as soon as Claude closes the pipe, including if Claude crashes, and nothing else
ever starts it.

## Security

- **One permission: Screen Recording**, which macOS requires to read another app's
  window. It only ever captures the QuickTime window. No camera, microphone,
  accessibility, network or file access.
- **The permission is iPadScreen's alone.** Claude starts extensions as separate apps,
  so they never borrow Claude's own permissions.
- **Signed ad hoc, on purpose.** macOS ties the permission to this exact build, so a
  modified copy gets nothing. The cost is allowing it again after each update.
- **Hardened Runtime is on** (the build fails without it), so no code can be injected
  into the app that holds the permission.
- **What it can't prevent:** a program already running as you could start the server
  and ask for a snapshot of the QuickTime window, as with any app you give this
  permission to. It can't see anything else on your screen.

## Development

| Command | Does |
|---|---|
| `just test` | Run the unit tests |
| `just build` | Build and sign `build/iPadScreen.app` |
| `just extension` | Build, pack `build/iPadScreen.mcpb` and open it in Claude |
| `just capture` | Take one snapshot from the terminal and open it (uses the terminal's Screen Recording permission) |
| `just skill-zip` / `just install-skill` | Package or link the `/ipad-explain` skill |

| Path | What |
|---|---|
| `Sources/iPadScreenCore` | MCP protocol, window choice, sizing, black-frame check, messages |
| `Sources/ipad-screen-mcp` | The server: the pipe loop and the ScreenCaptureKit capture |
| `Tests/iPadScreenCoreTests` | Unit tests |
| `Resources/manifest.json` | Extension manifest; the version lives here |
| `Resources/iPadScreen-Info.plist` | The app bundle's Info.plist |
| `scripts/build.sh`, `scripts/package-extension.sh` | Build and packaging |
| `skills/ipad-explain` | The tutoring skill |

## Licence

[MIT](LICENSE)
