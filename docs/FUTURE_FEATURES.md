# keepdash — Future Features

Planned enhancements for `keepdash.sh`. Ordered by the impact they would have
on daily use. These build on the current design — a dedicated, headless Chrome
dashboard controlled over HTTP (DevTools Protocol).

| # | Feature | Status |
|---|---------|--------|
| 1 | Automatic daemon mode | Planned |
| 2 | Session-expiry warning + re-login | ✅ Implemented (v1) |
| 3 | Random jitter on refresh interval | Planned |

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

## 2. Session-expiry warning + re-login ✅

**Implemented**: when the session has been alive for ~24 min (5 min before the
~29 min `TAsessionID` expiry), the cycle prints a warning and prompts:

```text
⚠  La sesión expira en ~5 min.
¿Abrir el navegador para re-login? [Y/n]
```

- **Y** (or Enter): stops headless, opens a visible Chrome window for SSO + 2FA,
  then resumes the invisible cycle automatically.
- **Anything else**: the cycle continues and will stop when the session dies.

After a successful re-login the timer resets for another ~24 min.

## 3. Random jitter on refresh interval

**Problem**: a mathematically precise interval (e.g. exactly every 240s) is a
detectable bot pattern. Humans don't refresh pages at exact regular intervals.

**Proposed approach**: add a random jitter of 0–30 seconds before each sleep,
so the effective interval varies between `INTERVAL-30` and `INTERVAL`. Trivial
to implement (`$RANDOM % 30`) with zero dependencies. Low risk — server-side
timing analysis is rare and expensive; the bigger detection vector is
`--headless=new`, not interval precision.