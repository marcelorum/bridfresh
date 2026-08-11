# keepdash — invisible session keep-alive for macOS

**keepdash.sh** keeps your web portal session alive using a **dedicated, invisible
Chrome dashboard** it controls over HTTP. Because it runs in a separate Chrome
profile it never touches your personal or work profiles, and because it runs
headless it **cannot** appear on screen, steal focus, or cut into your typing.

It rotates between your URLs on a schedule so the server sees an active user —
not a bot. No extra dependencies; plain shell + `curl` + Chrome's DevTools Protocol.

**Who it helps**: anyone with a portal, dashboard, or web app that logs you out
after a few minutes of inactivity — and that detects keep-alive plugins.

## Quick start

```bash
# 1. Clone the repo
git clone https://github.com/marcelorum/bridfresh.git
cd bridfresh

# 2. Make the script executable
chmod +x keepdash.sh

# 3. Create your config (private, gitignored)
cp config.example.conf config.conf

# 4. Add your dashboard URLs in config.conf
#    Edit the URLS=( ... ) block, one URL per line.

# 5. Run the invisible cycle — no separate login step needed
./keepdash.sh

#    First run: if not logged in, it asks
#    "¿Abrir el navegador para login? [Y/n]" — one key, no Enter needed.
#    Press Y (or just Enter): complete SSO + 2FA in the window that opens;
#    the script detects when the login is done and resumes invisible by
#    itself.
#    (./keepdash.sh --login still opens the login window manually if you prefer.)
```

The dashboard rotates your URLs headless every 4 minutes. Press `Ctrl+C` to stop,
or `./keepdash.sh --stop` from another terminal. Use `-d 1h` to auto-stop after
a duration.

> **Privacy note**: `config.conf` and `.dash-profile/` are private and
> gitignored — never commit them. `config.example.conf` is the only committed
> template.

## Repository layout

```
bridfresh/
├── keepdash.sh              → the main script (keep-alive dashboard)
├── config.conf              → PRIVATE, gitignored (your settings + URLs to cycle)
├── config.example.conf      → committed template for config.conf (shows the URLS= block)
├── .dash-profile/           → PRIVATE SSO profile, gitignored
├── legacy/keepalive.sh      → old script, kept for reference (do not use)
├── docs/MANUAL.md           → full usage manual
├── docs/FUTURE_FEATURES.md  → planned enhancements
└── README.md                → this page
```

## The essential flow

| Command | What it does |
|---------|--------------|
| `./keepdash.sh` | Run the **invisible** cycle (default 240 s / 4 min); asks to open the browser for login if you are not authenticated |
| `./keepdash.sh --login` | Open a **visible** window manually (SSO + 2FA) — optional, the script asks you on first run |
| `./keepdash.sh -d 1h` | Run the cycle for a limited time (`30m`, `1h`, `2h`…) |
| `./keepdash.sh --once` | One refresh, for testing |
| `./keepdash.sh --stop` | Shut down the dedicated dashboard |
| `./keepdash.sh --show` | Open a visible window to look at the dashboard |

Both on the first run (no session yet) and when the session expires mid-cycle,
the script detects a `login` page and asks **Y/n** whether to open the browser:
one key, no Enter needed — press `Y` (or just Enter) to open it; the script
detects on its own when the login is complete and resumes automatically.
Anything else stops the cycle.

## More documentation

- [Full usage manual](docs/MANUAL.md) — flags, config (`URLS=` + `INTERVAL`), troubleshooting
- [Planned features](docs/FUTURE_FEATURES.md)

## License

MIT
