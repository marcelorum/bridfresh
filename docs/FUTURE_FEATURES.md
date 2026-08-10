# keepdash — Future Features

Planned enhancements for `keepdash.sh`, none of them implemented yet. Ordered by
the impact they would have on daily use. These build on the current design — a
dedicated, headless Chrome dashboard controlled over HTTP (DevTools Protocol).

| # | Feature | Problem it solves |
|---|---------|-------------------|
| 1 | Automatic daemon mode | The script currently needs a terminal open (or a `--login` run first) |
| 2 | Expiry / status notification | You only find out the session died when the loop stops |
| 3 | Random jitter on refresh interval | A fixed interval is a detectable bot pattern |

## 1. Automatic daemon mode

**Problem**: keep-alive currently needs a terminal running the cycle. Closing the
terminal stops it, and after a reboot you must re-run `--login` and the loop.

**Proposed approach**: wrap the headless loop as a `launchd` LaunchAgent that
starts at login, reuses the stored SSO session in `.dash-profile/`, and runs
without a terminal window.

- The script already supports non-interactive modes (`--once`) and a clean stop
  (`--stop`), which a daemon wrapper can call.
- Logging needs a defined destination (e.g. a file under `~/Library/Logs/`)
  since stdout will no longer be a terminal.

## 2. Session-expiry / status notification

**Problem**: when the session expires, the loop stops and prints a message — but
only if you are watching the terminal. You may not realize keep-alive has stopped.

**Proposed approach**: when `dash_needs_auth()` triggers, post a macOS
notification (e.g. `osascript`/`notifyutil`) telling you to run `--login`, and/or
write status to a small state file the UI can read.

## 3. Random jitter on refresh interval

**Problem**: a mathematically precise interval (e.g. exactly every 240s) is a
detectable bot pattern. Humans don't refresh pages at exact regular intervals.

**Proposed approach**: add a random jitter of 0–30 seconds before each sleep,
so the effective interval varies between `INTERVAL-30` and `INTERVAL`. Trivial
to implement (`$RANDOM % 30`) with zero dependencies. Low risk — server-side
timing analysis is rare and expensive; the bigger detection vector is
`--headless=new`, not interval precision.