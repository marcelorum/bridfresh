# Session Keep-Alive

A native macOS script that keeps a web session alive by navigating the **real browser tab** where you are already logged in, rotating between URLs so the server sees an active user — not a bot.

Keep-alive browser plugins get detected by websites because they use artificial methods (headless requests, refreshing the home page). This script does none of that: it just points your existing Chrome, Safari, or Firefox tab at the next URL on a schedule.

**Who it helps**: anyone with a web portal, dashboard, or app that logs you out after a few minutes of inactivity — and that detects keep-alive plugins.

## Before you begin

The default config ships with placeholder URLs. **Edit `keepalive/config.conf` and replace them with your real URLs** before running. No URLs means the script refuses to start.

## Quick start

1. Edit `keepalive/config.conf` — set your `URLS`, `INTERVAL`, and which browsers to use.
2. Run it:

   ```bash
   cd keepalive
   ./keepalive.sh
   ```

3. Confirm it works: you should see the rotation loop in the terminal and your browser tab move between URLs. Press `Ctrl+C` to stop.

## Usage

```text
./keepalive.sh [flags] [url]
```

| Flag | Meaning |
|------|---------|
| `-c` | Use Google Chrome |
| `-f` | Use Firefox |
| `-s` | Use Safari |
| `-t <sec>` | Interval between rotations in seconds (default: from `config.conf`) |
| `-u <file>` | Read URLs from a `.txt` file, one per line (`#` comments ignored) |
| `-h` | Show help |
| `--list` | Show the current state (URLs, interval, browsers) without cycling |
| `--once <index>` | Navigate URL at that index once (for testing) |

Examples:

```bash
./keepalive.sh -c -f -t 300 urls.txt          # Chrome+Firefox, 5 min, URLs from file
./keepalive.sh -s https://example.com/a       # Safari only, single URL
./keepalive.sh -c -u urls.txt -t 120          # Chrome, URL file, 2 min
./keepalive.sh --list                         # show state, don't cycle
./keepalive.sh --once 2                       # navigate URL index 2 once
```

Rules that determine the behavior:

- **Browsers**: passing any of `-c`/`-f`/`-s` uses *only* those browsers. Without browser flags, `config.conf` values apply.
- **URL source priority**: `-u <file>` > URL passed as argument > `config.conf`.

## How it works

The script drives the browser you already have open, using the existing logged-in session.

| | Chrome / Safari | Firefox |
|---|---|---|
| Method | Native AppleScript: `set URL of active tab` | Keystroke simulation (`Cmd+L`, type URL, Enter) — Firefox does not expose URLs to AppleScript |
| Uses existing session | Yes | Yes |
| Brings window to front | No, if already running | Yes, always (known limitation) |

## Configuration

`config.conf` lives in `keepalive/`. It is sourced at startup and provides defaults for every flag.

| Setting | Values | Meaning |
|---------|--------|---------|
| `URLS=(...)` | array of URLs | Pages to rotate through, in order |
| `INTERVAL` | seconds | Time between rotations. `120` = 2 min, `300` = 5 min |
| `CHROME` / `SAFARI` / `FIREFOX` | `true` / `false` | Which browsers to control |
| `RELOAD_MODE` | `"navigate"` / `"force"` | `"force"` also reloads the page after navigating (Chrome/Safari) |

## Troubleshooting

| Problem | Cause / fix |
|---------|-------------|
| `ERROR: no hay URLs` | No URL source. Edit `config.conf`, pass `-u <file>`, or pass a URL as the last argument |
| Firefox steals focus every rotation | Expected — Firefox requires keystroke automation. Use Chrome/Safari if you need background navigation |
| Browser jumps to the front at start | The browser was not running; the first navigation launches it. Keep it running for background operation |
| Session still expires | Interval too long, or the portal needs real interaction. Tune `INTERVAL`; see Limitations |

## Limitations

- Firefox always comes to the front when navigated (keystroke requirement).
- The script navigates the **active tab**. If that tab has content you are using, it gets overwritten. (Planned: reuse an existing tab by domain.)
- Chrome and Safari navigate in the background without stealing focus, but only if the browser is already running.
- If a browser is not running, the first navigation launches it and brings it to front.
- A 2-minute interval may be overkill if your session only expires after 5–10 minutes of inactivity — tune it.
- Some portals require real mouse/keyboard interaction, not just navigation. This is not yet supported.

## License and roadmap

- License: MIT
- Planned features: [docs/FUTURE_FEATURES.md](docs/FUTURE_FEATURES.md)

## More documentation

- Full usage manual: [docs/MANUAL.md](docs/MANUAL.md)
