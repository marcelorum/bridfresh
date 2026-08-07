# keepdash — Future Features

Planned enhancements for `keepdash.sh`, none of them implemented yet. Ordered by
the impact they would have on daily use. These build on the current design — a
dedicated, headless Chrome dashboard controlled over HTTP (DevTools Protocol).

| # | Feature | Problem it solves |
|---|---------|-------------------|
| 1 | Reuse an existing tab by domain | Refreshing overwrites a tab you are actually using |
| 2 | Simulated mouse movement / scroll | Some portals need real interaction, not just navigation |
| 3 | Automatic daemon mode | The script currently needs a terminal open (or a `--login` run first) |
| 4 | Expiry / status notification | You only find out the session died when the loop stops |
| 5 | Better packaging and distribution | Keep-alive should be a single runnable install, not a repo clone |

## 1. Reuse an existing tab by domain

**Problem**: the dashboard refresh currently closes all tabs and opens the next
URL. That is fine for a dedicated invisible instance, but if you ever point it at
an existing profile, it would overwrite a tab you are using.

**Proposed approach**: before navigating, list the open tabs and navigate a tab
whose URL matches the target domain, falling back to opening the URL if none.

- The CDP already exposes all targets via `GET /json/list`, so matching by domain
  is feasible with the HTTP control the script already uses.

## 2. Simulated mouse movement / scroll

**Problem**: some portals only treat real user interaction (mouse move, scroll,
clicks) as activity; a simple navigation is not enough to keep the session alive.

**Proposed approach**: add an option to inject a small, varied, infrequent mouse
move or scroll into the dashboard via the DevTools Protocol (HTTP or websocket),
independent of the navigation interval.

- Technical note: synthetic input should stay small and irregular so it does not
  look scripted to anti-bot heuristics.

## 3. Automatic daemon mode

**Problem**: keep-alive currently needs a terminal running the cycle. Closing the
terminal stops it, and after a reboot you must re-run `--login` and the loop.

**Proposed approach**: wrap the headless loop as a `launchd` LaunchAgent that
starts at login, reuses the stored SSO session in `.dash-profile/`, and runs
without a terminal window.

- The script already supports non-interactive modes (`--once`) and a clean stop
  (`--stop`), which a daemon wrapper can call.
- Logging needs a defined destination (e.g. a file under `~/Library/Logs/`)
  since stdout will no longer be a terminal.

## 4. Session-expiry / status notification

**Problem**: when the session expires, the loop stops and prints a message — but
only if you are watching the terminal. You may not realize keep-alive has stopped.

**Proposed approach**: when `dash_needs_auth()` triggers, post a macOS
notification (e.g. `osascript`/`notifyutil`) telling you to run `--login`, and/or
write status to a small state file the UI can read.

## 5. Better packaging / distribution

**Problem**: today it is a repo with a script, a profile directory, and templates.
Sharing or installing it is not turnkey.

**Proposed approach**: explore shipping the script as a single-file installer or
app bundle that creates the needed files (`config.conf`, `urls.txt`) and the
`.dash-profile/` directory on first run, and preserves the same zero-dependency
design.