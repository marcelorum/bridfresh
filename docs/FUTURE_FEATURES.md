# keepdash — Future Features

Planned enhancements for `keepdash.sh`, none of them implemented yet. Ordered by
the impact they would have on daily use. These build on the current design — a
dedicated, headless Chrome dashboard controlled over HTTP (DevTools Protocol).

| # | Feature | Problem it solves |
|---|---------|-------------------|
| 1 | Automatic daemon mode | The script currently needs a terminal open (or a `--login` run first) |
| 2 | Session-expiry warning + re-login | You only find out the session died when the loop stops |
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

## 2. Session-expiry warning + re-login

**Problem**: when the session expires, the loop stops and prints a message — but
only if you are watching the terminal. You may not realize keep-alive has stopped.
Also, re-login requires manually running `--login`.

**Session lifetime** (investigated 2026-08-10): the `TAsessionID` cookie has a
fixed ~29 min server-assigned expiry. The `user.expiration` in sessionStorage
allows ~40 min. The keepalive refreshes Cloudflare tokens (`__cf_bm`) but NOT
the actual session cookies. No refresh tokens are exposed by the SSO — auto
re-login without 2FA is not possible.

**Proposed approach**: when the session has been alive for ~24 min (5 min before
the ~29 min expiry), print a warning and prompt:

```text
⚠ La sesión expira en ~5 min. Abrir el navegador para re-login? [Y/n]
```

- If user types `Y` or `yes` (or just hits Enter): launch `--login` window
  automatically, wait for the user to complete SSO + 2FA, then resume the
  headless cycle.
- If user types anything else or ignores: the loop continues and will stop
  naturally when the session dies.

The timer is based on elapsed time since the first successful refresh (not a
server-side token), so it's an estimate. Implementation: capture `START_TS` at
first successful refresh, warn when `now - START_TS >= 24 * 60`.

## 3. Random jitter on refresh interval

**Problem**: a mathematically precise interval (e.g. exactly every 240s) is a
detectable bot pattern. Humans don't refresh pages at exact regular intervals.

**Proposed approach**: add a random jitter of 0–30 seconds before each sleep,
so the effective interval varies between `INTERVAL-30` and `INTERVAL`. Trivial
to implement (`$RANDOM % 30`) with zero dependencies. Low risk — server-side
timing analysis is rare and expensive; the bigger detection vector is
`--headless=new`, not interval precision.

---

## Appendix: Session expiry investigation (2026-08-10)

**Method**: CDP cookie inspection (`monitor_cookies.js`) + HTTP header capture
(`monitor_headers.sh`) while `keepdash.sh` was running.

**Findings**:

| Cookie / Token | Lifetime | Renovable? |
|----------------|----------|------------|
| `TAsessionID` | ~29 min (fixed) | ❌ No — server-assigned, never renewed |
| `aep_session_id` | ~37 min (fixed) | ❌ No |
| `user.expiration` (sessionStorage) | ~40 min | ❌ No |
| `__cf_bm` (Cloudflare) | Rolling 30 min | ✅ Yes — refreshed every request |
| `_cfuvid` (Cloudflare) | Session | ✅ Yes |
| `cf_clearance` | 1 year | ✅ N/A — long-lived |

**Key observations**:
- The keepalive refreshes Cloudflare bot management tokens but NOT the actual
  session cookies. The session has a hard server-side lifetime.
- No OAuth refresh tokens are stored anywhere (cookies, localStorage, sessionStorage).
  The SSO does not expose a renewable token flow to the client.
- At 4 min intervals, the script gets ~16 cycles (~64 min) because Cloudflare
  stays happy. At 5 min intervals, only ~4 cycles (~20 min) — Cloudflare may
  cut earlier due to sparse request pattern.
- The real bottleneck is `TAsessionID` (~29 min). To go beyond that would require
  either a refresh token (not available) or a semi-automatic re-login (feature #2).