# keepdash — Usage Manual

The complete reference for `keepdash.sh`: a dedicated, invisible Chrome-based
dashboard that keeps your session alive by rotating URLS on a schedule.

## Contents

- [keepdash — Usage Manual](#keepdash--usage-manual)
  - [Contents](#contents)
  - [Requirements](#requirements)
  - [How it works](#how-it-works)
  - [First time: log in when prompted](#first-time-log-in-when-prompted)
  - [Daily use — the invisible cycle](#daily-use--the-invisible-cycle)
  - [Command-line flags](#command-line-flags)
    - [Flag semantics](#flag-semantics)
  - [Example uses](#example-uses)
  - [URL configuration](#url-configuration)
  - [Configuration reference](#configuration-reference)
  - [Session state](#session-state)
  - [Troubleshooting](#troubleshooting)
    - [The dashboard asks to log in again](#the-dashboard-asks-to-log-in-again)
    - [Nothing happens / the script asks about auth at startup](#nothing-happens--the-script-asks-about-auth-at-startup)
    - [The cycle feels too busy or too slow](#the-cycle-feels-too-busy-or-too-slow)
    - [I want to see what it's doing](#i-want-to-see-what-its-doing)
    - [I want to stop it](#i-want-to-stop-it)
    - [Stuck: the script reports the dashboard did not start](#stuck-the-script-reports-the-dashboard-did-not-start)
  - [FAQ](#faq)
  - [More documentation](#more-documentation)

## Requirements

- macOS with Google Chrome installed (default path:
  `/Applications/Google Chrome.app`).
- bash (the one shipped on macOS — no bash 4 features are required).
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

## First time: log in when prompted

You don't need a separate login step — just start the cycle:

```bash
./keepdash.sh
```

1. The script launches the dashboard **headless** (invisible).
2. If you are not logged in yet (fresh profile or expired session), it prints:

   ```text
   El dashboard no esta autenticado (primera vez o sesion nueva).
   ¿Abrir el navegador para login? [Y/n]
   ```

3. Press `Y` (or Enter) — a single key, no Enter required: the script switches
   to a **visible** Chrome window.
4. Log in normally (SSO + 2FA).
5. That's it: the script notices on its own when the login is finished and
   resumes the invisible cycle by itself.

Your session is saved into `.dash-profile/` (cookies) and reused by the headless
cycle from then on. Shutting Chrome down or stopping the dashboard **does not**
log you out.

`./keepdash.sh --login` still works if you prefer to open the visible window
manually.

## Daily use — the invisible cycle

```bash
./keepdash.sh
```

Starts the dedicated dashboard headless and cycles through your URLs every
`interval` seconds (default 240 s / 4 min). The terminal shows a timestamp and which
dashboard was refreshed:

```text
Navegador-dashboard invisible arriba.
Alternando invisible. Ciclo: 240s, 3 URL(s).
Para detener:      ./keepdash.sh --stop
Para ver/login:     ./keepdash.sh --login
---
[16:45:00]
   refresca > https://tu-web.com/dashboard
```

Stop it with `Ctrl+C` (prints `Detenido.` and shuts down headless cleanly) or
`./keepdash.sh --stop`.

### Session expiry re-login

When the cycle detects that the session has expired (the browser redirected to
a `login`/`okta` page), it prints a prompt:

```text
La sesion expiro.
¿Abrir el navegador para re-login? [Y/n]
```

- **Y** (or Enter): a single keypress (no Enter needed) — stops headless, opens a
  visible Chrome window for you to complete SSO + 2FA, then resumes the invisible
  cycle automatically once it detects the login is done.
- **Anything else**: the cycle stops and tells you to run `./keepdash.sh --login`
  manually.

The same prompt appears when you start the script without a session
("El dashboard no esta autenticado (primera vez o sesion nueva)."), so a fresh
setup needs no `--login` before the first run.

> Note: the server assigns the session a fixed lifetime of roughly an hour.
> Refreshing more often (a shorter `INTERVAL`) does not extend it; it only
> changes how frequently the dashboards are visited.

## Command-line flags

| Flag | Argument | Effect |
|------|----------|--------|
| `-h` / `--help` | — | Print the help text and exit |
| `-t` | `<sec>` | Interval between refreshes, in seconds (default: `config.conf`) |
| `-d` | `<dur>` | Total runtime: `30m`, `1h`, `2h` or plain minutes. The cycle stops by itself when reached (no limit by default) |
| `-u` | `<file>` | Read URLs from a file (overrides the `URLS=` in `config.conf`) |
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
- `-d <dur>` limits how long the cycle runs: `30m`, `1h`, `2h`, or a plain
  number of minutes such as `90`. When the time is up, it shuts down and exits
  cleanly; without `-d` it runs until `Ctrl+C` or `--stop`.
- `-u <file>` must point to an existing file, or the script exits with an error.
  When given, it overrides the URLs defined in `config.conf`.

## Example uses

```bash
./keepdash.sh               # headless, 240s default (4 min)
./keepdash.sh -t 300        # refresh every 5 minutes
./keepdash.sh -d 90m        # run for 90 minutes, then stop by itself
./keepdash.sh -d 2h         # run for 2 hours
./keepdash.sh -u myurls.txt # URLs from a specific file (overrides config.conf)
./keepdash.sh --once        # one refresh to test
./keepdash.sh --show        # open the dashboard to look at it
./keepdash.sh --stop        # shut the dashboard down
./keepdash.sh --login       # authenticate (SSO + 2FA)
```

## URL configuration

Your URLs to cycle live in **`config.conf`** (private, gitignored), under the
`URLS=( ... )` array — one URL per line, in cycling order:

```text
URLS=(
  "https://tu-web.com/dashboard"
  "https://tu-web.com/lista"
)
```

Rules:

- One URL per line, cycled in array order.
- Empty lines are ignored.
- Lines starting with `#` are ignored (inline comments too).
- Whitespace around each line is trimmed.
- Quoting each URL is optional.

The script reads `URLS=` from `config.conf` by default, so `./keepdash.sh` runs
your real dashboards with no extra arguments. If `config.conf` defines no URLs,
the script falls back to a single built-in default URL.

`-u <file>` still accepts a plain-text URL list (same rules as above) and
**overrides** the config URLs — useful for a one-off rotation. If that file does
not exist, the script exits with an error.

## Configuration reference

`config.conf` sits in the repository root, next to the script, and is read
automatically — it is **private and gitignored**. Copy the template to create it:

```bash
cp config.example.conf config.conf
```

Today the script reads the URLs to cycle and the default interval from it:

| Setting | Default | Values | Meaning |
|---------|---------|--------|---------|
| `URLS=( ... )` | `URLS=()` | URL list | URLs to cycle, one per line (used by default) |
| `INTERVAL` | `240` | seconds | Time between refreshes, in seconds |

Other keys in `config.example.conf` are carried over from the legacy script and
are not used by `keepdash.sh` yet. Keep the file to set your default URLs and
interval; the `-u` and `-t` flags override them.

## Session state

The SSO session lives in `.dash-profile/` (gitignored, private). Because the
headless cycle reuses the profile's cookies, you log in once and the session
survives Chrome restarts and `--stop`/`--start` cycles. Deleting `.dash-profile/`
logs you out — the script will ask you to log in again on the next run.

## Troubleshooting

### The dashboard asks to log in again

When the session expires, the cycle detects the login page and prompts you with
**Y/n** (one key, no Enter). Press `Y` (or Enter) to open the login window,
complete SSO + 2FA — the script detects the login on its own and resumes
automatically. Anything else stops the script.

If you declined, run `./keepdash.sh --login`, log in again, then restart
`./keepdash.sh`.

### Nothing happens / the script asks about auth at startup

On a fresh profile the headless mode may land on a login page. The script
detects it and asks **Y/n** (one key) to open the login window: press `Y`,
complete SSO + 2FA — no confirmation needed, the script detects the login and
resumes by itself. If you prefer a manual window, decline and run
`./keepdash.sh --login`.

### The cycle feels too busy or too slow

Tune the interval. If your session expires after ~5 minutes, `240` (4 min)
is the safe default; `120` if it expires faster.

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
No. On the first run the script asks you to open the login window; after that,
the headless cycle reuses that session until it expires (roughly an hour). When
it does, the script offers to open the login window again with the **Y/n**
prompt.

**Q: Will stopping the script log me out?**
No. Shutting the dashboard down does not destroy the SSO session cookies.

**Q: Is this detectable like keep-alive plugins?**
Plugins get flagged for artificial traffic (headless requests, forced home-page
refreshes). This performs real navigation in a real browser, indistinguishable
from a human clicking — and your real browser is untouched.

## More documentation

- [Planned features](FUTURE_FEATURES.md)