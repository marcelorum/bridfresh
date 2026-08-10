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

# 2. Create your config (private, gitignored)
cp config.example.conf config.conf

# 3. Add your dashboard URLs in config.conf
#    Edit the URLS=( ... ) block, one URL per line.

# 4. First-time login — opens a visible Chrome window (SSO + 2FA)
./keepdash.sh --login

# 5. Run the invisible cycle
./keepdash.sh
```

The dashboard rotates your URLs headless every 5 minutes. Press `Ctrl+C` to stop,
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
| `./keepdash.sh --login` | Open a **visible** window once to authenticate (SSO + 2FA) |
| `./keepdash.sh` | Run the **invisible** cycle (default 300 s / 5 min) |
| `./keepdash.sh -d 1h` | Run the cycle for a limited time (`30m`, `1h`, `2h`…) |
| `./keepdash.sh --once` | One refresh, for testing |
| `./keepdash.sh --stop` | Shut down the dedicated dashboard |
| `./keepdash.sh --show` | Open a visible window to look at the dashboard |

If your session expires, the cycle detects a `login` page and tells you to run
`./keepdash.sh --login` again — it does not try to log you back in on its own.

## More documentation

- [Full usage manual](docs/MANUAL.md) — flags, config (`URLS=` + `INTERVAL`), troubleshooting
- [Planned features](docs/FUTURE_FEATURES.md)

## License

MIT
