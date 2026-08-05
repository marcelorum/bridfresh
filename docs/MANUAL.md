# Session Keep-Alive — Usage Manual

The complete reference for `keepalive.sh`, a macOS-native script that keeps a web session alive by rotating URLs in the real browser tab where you are already logged in.

## Contents

1. [Requirements](#requirements)
2. [Getting started](#getting-started)
3. [Command-line flags](#command-line-flags)
4. [Examples with expected output](#examples-with-expected-output)
5. [URL sources and priority](#url-sources-and-priority)
6. [Configuration reference](#configuration-reference)
7. [URL file format](#url-file-format)
8. [How browser automation works](#how-browser-automation-works)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

## Requirements

- macOS only (uses `osascript`). The script exits with an error on any other OS.
- bash 3.2 (the default on macOS).
- One or more of: Google Chrome, Safari, Firefox.
- No external dependencies and nothing to install.

## Getting started

1. **Edit `config.conf`** with your real URLs. The shipped file contains placeholders (`tu-web.com/...`) and the script refuses to start with an empty URL list.
2. **Run the script** from the `keepalive/` directory:

   ```bash
   cd keepalive
   ./keepalive.sh
   ```

3. **Verify**: the terminal prints the rotation list, then a `[HH:MM:SS] -> URL` line each time the tab navigates. Press `Ctrl+C` to stop.

The script requires no installation: `config.conf` is loaded automatically from the same directory as the script, so run it from `keepalive/` (or any directory — the script resolves its own config path).

## Command-line flags

| Flag | Argument | Effect |
|------|----------|--------|
| `-c` | — | Use Google Chrome |
| `-f` | — | Use Firefox |
| `-s` | — | Use Safari |
| `-t` | `<sec>` | Interval between rotations, in seconds. Overrides `INTERVAL` from `config.conf` |
| `-u` | `<file>` | Read URLs from a text file, one per line. Overrides `URLS` from `config.conf` |
| `-h` | — | Print the help text and exit |
| `--list` | — | Print the current state (URLs, interval, browsers) and exit without cycling |
| `--once` | `<index>` | Navigate the URL at that index once and exit. For testing |

`--list` and `--once` can appear anywhere in the command line, before or after other flags.

### Browser flag semantics

- If **any** of `-c`, `-f`, `-s` is passed, only those browsers are used and the browser settings in `config.conf` are ignored.
- If **none** are passed, the `CHROME` / `SAFARI` / `FIREFOX` values in `config.conf` apply.
- Passing multiple browser flags is valid: the URL is navigated in each selected browser. Example: `-c -f` rotates in Chrome and Firefox.

### Interval flag semantics

`-t <sec>` accepts any positive number of seconds. `INTERVAL` from `config.conf` is used only when `-t` is absent. There is no minimum enforced — use common sense so the traffic looks natural.

## Examples with expected output

### Default run (config.conf)

```bash
./keepalive.sh
```

Startup output:

```text
URLs en rotacion:
  [0] https://tu-web.com/dashboard
  [1] https://tu-web.com/lista
  [2] https://tu-web.com/perfil
Intervalo: 120s
Browsers: Chrome=true Safari=true Firefox=true
---
[12:00:00] -> https://tu-web.com/dashboard
[12:02:00] -> https://tu-web.com/lista
```

The loop rotates through the configured URLs forever, waiting `INTERVAL` seconds between each. `Ctrl+C` prints `Detenido.` and exits.

### Chrome + Firefox, 5-minute interval, URLs from file

```bash
./keepalive.sh -c -f -t 300 urls.txt
```

Rotates through the URLs in `urls.txt` every 5 minutes, in both Chrome and Firefox. The startup output shows `Browsers: Chrome=true Safari=false Firefox=true`.

### Safari only, single URL

```bash
./keepalive.sh -s https://example.com/a
```

Rotates that single URL in Safari every `INTERVAL` seconds (from config, since `-t` is absent). A single-URL rotation re-navigates the same page repeatedly, which still counts as activity. The startup output appends `(URL directa: usa solo esa)`.

### Chrome, URL file, 2-minute interval

```bash
./keepalive.sh -c -u urls.txt -t 120
```

Reads `urls.txt`, cycles every 2 minutes, Chrome only.

### Show current state without cycling

```bash
./keepalive.sh --list
```

```text
URLs en rotacion:
  [0] https://tu-web.com/dashboard
  [1] https://tu-web.com/lista
  [2] https://tu-web.com/perfil
Intervalo: 120s
Browsers: Chrome=true Safari=true Firefox=true
```

Exits immediately. Useful to confirm what the script would do before starting the loop.

### One-shot navigation (testing)

```bash
./keepalive.sh --once 2
```

```text
Navegando [2] -> https://tu-web.com/perfil
```

Navigates the URL at index 2 in all enabled browsers once, then exits. Useful for verifying a browser integration without starting the loop.

### Stopping the loop

Press `Ctrl+C` in the terminal running the script. The loop stops and prints `Detenido.`.

## URL sources and priority

URLs can come from three places. When more than one is present, the first in this list wins:

| Priority | Source | How |
|----------|--------|-----|
| 1 | `-u <file>` | Text file, one URL per line |
| 2 | Positional argument | URL passed as the last argument |
| 3 | `config.conf` | `URLS=(...)` array |

If the result is an empty URL list, the script exits with an error:

```text
ERROR: no hay URLs. Usa config.conf, -u <archivo> o una URL al final.
```

## Configuration reference

`config.conf` sits next to the script in `keepalive/` and is sourced as a bash file.

| Setting | Default | Values | Meaning |
|---------|---------|--------|---------|
| `URLS` | placeholders | array of strings | Pages to rotate through, in order |
| `INTERVAL` | `120` | seconds | Time between rotations. `120` = 2 min, `300` = 5 min |
| `CHROME` | `true` | `true` / `false` | Control Google Chrome |
| `SAFARI` | `true` | `true` / `false` | Control Safari |
| `FIREFOX` | `true` | `true` / `false` | Control Firefox |
| `RELOAD_MODE` | `"navigate"` | `"navigate"` / `"force"` | `"force"` also reloads the page after navigating |

### RELOAD_MODE details

- `"navigate"` (default): navigate to the URL only.
- `"force"`: navigate to the URL, then reload the tab. Produces a more visible "load" on screen.
- Applies to Chrome and Safari. Firefox always navigates via keystrokes and does not reload.

Placeholders in the shipped file use `tu-web.com` — replace them with real URLs. Comments with `#` are allowed throughout the file.

## URL file format

The file passed to `-u <file>` is plain text:

- One URL per line, cycled in file order.
- Empty lines are ignored.
- Lines starting with `#` are ignored.
- Inline comments: everything after a `#` on a line is ignored.
- Whitespace around each line is trimmed.

Example (`urls.txt`):

```text
# Una URL por linea, cicla en este orden
https://tu-web.com/dashboard
https://tu-web.com/lista
https://tu-web.com/perfil
# Las lineas con # se ignoran (como esta)
```

Passing a nonexistent file exits with an error:

```text
ERROR: archivo 'nope.txt' no existe
```

## How browser automation works

The script drives the real browser process and its existing logged-in session. It never sends headless requests.

| Aspect | Chrome | Safari | Firefox |
|--------|--------|--------|---------|
| Automation method | AppleScript: `set URL of active tab of front window` | AppleScript: `set URL of current tab of front window` | Keystroke simulation: `Cmd+L`, type URL, Enter |
| Session reuse | Yes — existing tab, existing login | Yes — existing tab, existing login | Yes — existing tab, existing login |
| Brings window to front | No, when already running | No, when already running | Yes, always |
| First launch behavior | Opens the app and brings it to front | Opens the app and brings it to front | Opens the app and brings it to front |
| `RELOAD_MODE="force"` | Reloads the tab after navigating | Runs `location.reload()` via JavaScript | Not supported |

Chrome and Safari allow true background navigation: the script updates the tab's URL without activating the window, so you can keep working while the session stays alive. Firefox has no AppleScript URL control, so the script simulates the human shortcut (`Cmd+L`, paste, `Enter`), which necessarily brings Firefox to the front.

## Troubleshooting

### Firefox comes to the front on every rotation

Expected. Firefox does not expose tab URLs to AppleScript, so the script simulates keystrokes, which requires the app to be active. If background navigation matters to you, use Chrome or Safari for the keep-alive browser and leave Firefox alone.

### A browser jumps to the front when the script starts

The browser was not running, so the first navigation launched it. Keep the browsers running in the background before starting the script; Chrome and Safari then navigate without stealing focus.

### The session still expires

Check, in order:

1. **Interval too long.** If the portal logs out after, say, 10 minutes of inactivity, an `INTERVAL` of 300 seconds (5 min) is comfortable; 120 seconds (2 min) is safest but may be overkill.
2. **The portal needs real interaction.** Some portals require actual mouse/keyboard input, not just navigation. Simulated mouse movement is a planned feature (see `FUTURE_FEATURES.md`), not yet implemented.
3. **The wrong browser is being controlled.** Confirm the startup output lists the browsers you expect: `Browsers: Chrome=... Safari=... Firefox=...`. If you passed a browser flag, only those browsers are used.

### The script prints a URL error

| Error | Cause | Fix |
|-------|-------|-----|
| `ERROR: no hay URLs...` | URL list is empty | Edit `config.conf`, pass `-u <file>`, or pass a URL as the last argument |
| `ERROR: archivo 'X' no existe` | `-u` file not found | Check the path and filename |
| `ERROR: index N no existe (max M)` | `--once` index out of range | Use `./keepalive.sh --list` to see valid indexes |
| `ERROR: esto es para macOS` | Run on a non-macOS system | This script is macOS-only |

### Nothing happens when `--once` runs

Verify the browser is enabled (a browser flag or a `true` in `config.conf`) and is installed. If the browser is closed, the first navigation launches it — this can take a moment. `--once` prints the target URL before navigating, so check that the printed URL is correct.

## FAQ

**Q: Does this log me in again or create a new session?**
No. It reuses the existing tab and the session already open in that browser. That is the whole point: the server sees the same active user.

**Q: Is this detectable like keep-alive plugins?**
Plugins are detected because they use artificial traffic (headless requests, refreshing the home page). This script performs real navigation inside the real browser tab, which is indistinguishable from a human clicking links.

**Q: How do I make the traffic look more natural?**
Add more distinct URLs to the list so each rotation looks like a different page visit, and set `INTERVAL` so it is not unnaturally frequent.

**Q: Can I use more than one browser at once?**
Yes. Pass multiple flags (`-c -f`) or set multiple booleans to `true` in `config.conf`. Each rotation navigates the same URL in every enabled browser.

**Q: Can I run this as a background daemon?**
Not yet. It currently needs a terminal open. Running as a background agent is a planned feature (see `FUTURE_FEATURES.md`).

**Q: What happens if I navigate the active tab myself while the script runs?**
The script overwrites whatever is in the active tab. Reusing an existing tab by domain instead is a planned feature (see `FUTURE_FEATURES.md`).

**Q: Is there a minimum interval?**
No hard minimum, but intervals below a couple of minutes look automated. Match the interval to the portal's actual inactivity timeout.
