# keepdash — Usage Manual

The complete reference for `keepdash.sh`: a dedicated, invisible Chrome-based
dashboard that keeps your session alive by rotating URLS on a schedule.

## Contents

1. [Requirements](#requirements)
2. [How it works](#how-it-works)
3. [First time: login once](#first-time-login-once)
4. [Daily use: the invisible cycle](#daily-use-the-invisible-cycle)
5. [Command-line flags](#command-line-flags)
6. [Examples](#examples)
7. [URL file format](#url-file-format)
8. [Configuration reference](#configuration-reference)
9. [Session expiration](#session-expiration)
10. [Troubleshooting](#troubleshooting)
11. [FAQ](#faq)

## Requirements

- macOS with Google Chrome installed (default path:
  `/Applications/Google Chrome.app`).
- bash (the one shipped on macOS).
- `curl` (preinstalled).
- No other dependencies, nothing to install.

## How it works

`keepdash.sh` launches **its own copy of Chrome** with:

- a **dedicated profile** (`<repo>/.dash-profile/`) — separate from your personal
  and work profiles, so it never touches your existing sessions;
- the Chrome DevTools Protocol listening on local port `9222`.

The script controls that instance over HTTP with plain `curl`:
open a URL, close tabs, list open targets. It rotates between your URLs every
`INTERVAL` seconds so the server sees an active user.

The cycle runs in **`--headless=new`** mode. Chrome is invisible and never grabs
focus, so it cannot interrupt your typing or steal the window.

### Why a dedicated dashboard instead of your real browser

The previous script (`legacy/keepalive.sh`) navigated your real browser tab and
could bring Chrome to the front. This version replaces that: it uses its own
dedicated instance, so your browsing is untouched and the loop is truly invisible.
The legacy script is kept in `legacy/` only for reference — **do not use it**.

## First time: login once

You authenticate **one time**, in a visible window:

```bash
./keepdash.sh --login
```

1. A Chrome window opens on your first URL.
2. Log in normally (SSO + 2FA).
3. Close the window (or leave it) and run the daily command below.

Your session is saved into `.dash-profile/` (cookies). It is reused by the
headless cycle from then on. Shutting Chrome down or stopping the dashboard
**does not** log you out.

You only ever need `--login` again when the session expires.

## Daily use — the invisible cycle

```bash
./keepdash.sh
```

Starts the dedicated dashboard headless and cycles through your URLs every
`interval` seconds (default 120 s). The terminal shows a timestamp and which
dashboard was refreshed:

```text
Navegador-dashboard invisible arriba.
Alternando invisible. Ciclo: 120s, 3 URL(s).
Para detener:      ./keepdash.sh --stop
Para ver/login:     ./keepdash.sh --login
---
[16:45:00]
   refresca > https://tu-web.com/dashboard
```

Stop it with `Ctrl+C` (prints `Detenido.` and shuts down headless cleanly) or
`./keepdash.sh --stop`.

## Command-line flags

| Flag | Argument | Effect |
|------|----------|--------|
| `-h` / `--help` | — | Print the help text and exit |
| `-t` | `<sec>` | Interval between refreshes, in seconds (default: `config.conf`) |
| `-u` | `<file>` | Read URLs from a file, one per line |
| `--login` | — | Open a **visible** window to authenticate (or to view) |
| `--once` | — | One refresh, then exit (for testing) |
| `--stop` | — | Shut down the dedicated dashboard |
| `--show` | — | Open a **visible** window to view the dashboard |

### Flag semantics

- `--login` and `--show` both start the dashboard with a visible window.
  `--login` is for authenticating; `--show` is to look at it. Either way, return
  to the headless cycle afterwards with `./keepdash.sh`.
- `--once` does a single headless refresh of the **first** URL and exits. Good
  for verifying the setup.
- `-t <sec>` overrides the interval. Any positive value works; match it to the
  portal's actual inactivity timeout.
- `-u <file>` must point to an existing file, or the script exits with an error.

## Example uses

```bash
./keepdash.sh               # headless, 120s default
./keepdash.sh -t 300        # refresh every 5 minutes
./keepdash.sh -u myurls.txt # URLs from a specific file
./keepdash.sh --once        # one refresh to test
./keepdash.sh --show        # open the dashboard to look at it
./keepdash.sh --stop        # shut the dashboard down
./keepdash.sh --login       # authenticate (SSO + 2FA)
```

## URL file format

The file passed to `-u <file>`, or the default `urls.txt`, is plain text:

- One URL per line, cycled in file order.
- Empty lines are ignored.
- Lines starting with `#` are ignored.
- Everything after a `#` on a line is ignored (inline comments).
- Whitespace around each line is trimmed.

Example (`urls.txt`):

```text
# one URL per line, cycled in this order
https://tu-web.com/dashboard
https://tu-web.com/lista
https://tu-web.com/perfil
```

The script picks **`urls.txt` next to it automatically** if present, so you run
`./keepdash.sh` with no `-u` and it still uses your real URLs. If you pass `-u`,
that file wins. If the file does not exist, the script exits with an error.

## Configuration reference

`config.conf` sits in the repository root, next to the script, and is read
automatically — it is **private and gitignored**. Copy the template to create it:

```bash
cp config.example.conf config.conf
```

Today the script reads **`INTERVAL`** from it as the default interval:

| Setting | Default | Values | Meaning |
|---------|---------|--------|---------|
| `INTERVAL` | `120` | seconds | Time between refreshes, in seconds |

Other keys in `config.example.conf` are carried over from the legacy script and
are not used by `keepdash.sh` yet. Keep the file if you want to set a default
interval; the `-t` flag overrides it.

## Session state

The SSO session lives in `.dash-profile/` (gitignored, private). Because the
headless cycle reuses the profile's cookies, you log in once and the session
survives Chrome restarts and `--stop`/`--start` cycles. Deleting `.dash-profile/`
logs you out — you would need to re-authenticate with `--login`.

## Troubleshooting

### The dashboard asks to log in again

The cycle checks for a `login`/`okta` page in two points — before each refresh
and right after it. If it finds one, it stops the dashboard and tells you:

```text
La session expiro. Corre  ./keepdash.sh --login  para autenticar de nuevo.
```

Run `./keepdash.sh --login`, log in again, then restart `./keepdash.sh`.

### Nothing happens / it exits saying the dashboard asks for auth

On a fresh profile the headless mode may land on a login page, with no visible
window, and ask you to authenticate. Run `./keepdash.sh --login` once, then
`./keepdash.sh`.

### The cycle feels too busy or too slow

Tune the interval. If your session expires after ~5 minutes, `-t 300` (or
`INTERVAL=300`) is comfortable; `120` is the safe default.

### I want to see what it's doing

- `./keepdash.sh --show` opens a visible window with the dashboard.
- `./keepdash.sh --once` does a single headless refresh so you can watch the log.

### I want to stop it

`Ctrl+C` stops the cycle (it prints `Detenido.` and shuts down the dashboard), or
run `./keepdash.sh --stop` from another terminal.

### Stuck: the script reports the dashboard did not start

If a previous instance from the same profile is still running, the script kills
it on boot. If a bad profile blocks
startup, the boot retries up to ~20 s then exits with an error. Check that the
dedicated profile is not locked:

```bash
./keepdash.sh --stop
```

## FAQ

**Q: Does this touch my normal Chrome/Safari/Firefox?**
No. It launches its own Chrome with its own profile (`.dash-profile/`). Your
personal and work profiles are never touched.

**Q: Will Chrome appear on screen?**
No. The cycle runs headless (`--headless=new`). It cannot show a window, steal
focus, or interrupt typing. The only visible window is the one you open with
`--login` or `--show`.

**Q: Do I have to log in every time?**
No. You authenticate once with `--login`; the headless cycle reuses that session
indefinitely until it expires.

**Q: Will stopping the script log me out?**
No. Shutting the dashboard down does not destroy the SSO session cookies.

**Q: Is this detectable like keep-alive plugins?**
Plugins get flagged for artificial traffic (headless requests, forced home-page
refreshes). This performs real navigation in a real browser, indistinguishable
from a human clicking — and your real browser is untouched.

## More documentation

- [Planned features](FUTURE_FEATURES.md)