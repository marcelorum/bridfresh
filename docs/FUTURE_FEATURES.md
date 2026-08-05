# Session Keep-Alive — Future Features

Planned enhancements, none of them implemented yet. Ordered by the impact they would have on daily use.

| # | Feature | Problem it solves |
|---|---------|-------------------|
| 1 | Reuse an existing tab by domain | Navigating the active tab overwrites tabs you are actually using |
| 2 | Simulated mouse movement / scroll | Some portals require real interaction, not just navigation |
| 3 | Run as a background agent | The script currently needs a terminal open |

## 1. Reuse an existing tab by domain

**Problem**: the script navigates the **active tab** of the front window. If that tab holds content you are using, it gets overwritten on every rotation.

**Proposed approach**: before navigating, search the open tabs for one whose URL matches the target domain and navigate *that* tab. Fall back to creating a new tab when no match exists.

- Recommended strategy: match by **domain**, not full URL, so the same domain's tabs are reused even when the target path differs. Fall back to `make new tab` when nothing matches.
- Chrome exposes all windows and tabs to AppleScript by iterating:

  ```applescript
  repeat with w in windows
    repeat with t in tabs of w
      get URL of t
    end repeat
  end repeat
  ```

- Technical note: the same iteration pattern is available for Safari. Firefox remains a constraint, since it does not expose tab URLs to AppleScript at all.

## 2. Simulated mouse movement / scroll

**Problem**: some portals only treat real user interaction (mouse movement, scroll) as activity; simple page navigation is not enough to keep the session alive.

**Proposed approach**: add an option that, on each rotation (or on an independent timer), simulates a small mouse move or scroll via AppleScript `System Events`. This is the same mechanism already used for Firefox keystrokes.

- Technical note: the current implementation already drives `System Events` for Firefox, so the infrastructure to send synthetic events exists in the codebase.
- Technical note: synthetic mouse events may trigger a different class of anti-bot heuristics (input events at fixed coordinates look scripted). If adopted, movement should be small, varied, and infrequent to stay under the radar.

## 3. Run as a background agent / daemon

**Problem**: the script needs a terminal open for its whole run. Closing the terminal stops the keep-alive.

**Proposed approach**: wrap the rotation loop as a launchd agent (LaunchAgent) that starts at login and runs without a terminal window.

- Technical note: the script already accepts a `--list` mode and a `--once` mode, so it can be invoked non-interactively; a daemon wrapper would run the main loop with logging to a file instead of the terminal.
- Technical note: logging and error visibility need a defined destination (e.g., a log file under `~/Library/Logs/`) since stdout will no longer be a terminal.
