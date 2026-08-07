# keepdash — invisible session keep-alive for macOS

**keepdash.sh** keeps your web portal session alive using a **dedicated, invisible
Chrome dashboard** it controls over HTTP. Because it runs in a separate Chrome
profile it never touches your personal or work profiles, and because it runs
headless it **cannot** appear on screen, steal focus, or cut into your typing.

It rotates between your URLs on a schedule so the server sees an active user —
not a bot. No extra dependencies; plain shell + `curl` + Chrome's DevTools Protocol.

**Who it helps**: anyone with a portal, dashboard, or web app that logs you out
after a few minutes of inactivity — and that detects keep-alive plugins.

## Repository layout

```
bridfresh/
├── keepdash.sh              → the main script (keep-alive dashboard)
├── config.conf              → PRIVATE, gitignored (your settings)
├── urls.txt                 → PRIVATE, gitignored (your URLs)
├── config.example.conf      → committed template for config.conf
├── urls.example.txt          → committed template for urls.txt
├── .dash-profile/           → PRIVATE SSO profile, gitignored
├── legacy/keepalive.sh      → old script, kept for reference (do not use)
├── docs/MANUAL.md           → full usage manual
├── docs/FUTURE_FEATURES.md  → planned enhancements
└── README.md                → this page
```

## Quick start

First-time setup (**this is the only time you see a window**):

```bash
./keepdash.sh --login
```

Log into the dashboard (SSO + 2FA). The session is saved to `.dash-profile/`.
From then on, just start the invisible cycle:

```bash
./keepdash.sh
```

That's it. The dedicated dashboard rotates your URLs in the background, headless,
every 120 seconds. Press `Ctrl+C` to stop, or run `./keepdash.sh --stop`.

> **Privacy note**: `config.conf`, `urls.txt`, and `.dash-profile/` are private and
> gitignored — they contain your real targets and your SSO session. Never commit
> them. `config.example.conf` and `urls.example.txt` are the committed templates.

## The essential flow

| Command | What it does |
|---------|--------------|
| `./keepdash.sh --login` | Open a **visible** window once to authenticate (SSO + 2FA) |
| `./keepdash.sh` | Run the **invisible** cycle (default 120 s) |
| `./keepdash.sh --once` | One refresh, for testing |
| `./keepdash.sh --stop` | Shut down the dedicated dashboard |
| `./keepdash.sh --show` | Open a visible window to look at the dashboard |

If your session expires, the cycle detects a `login` page and tells you to run
`./keepdash.sh --login` again — it does not try to log you back in on its own.

## More documentation

- [Full usage manual](docs/MANUAL.md) — flags, config, `urls.txt`, troubleshooting
- [Planned features](docs/FUTURE_FEATURES.md)

## License

MIT