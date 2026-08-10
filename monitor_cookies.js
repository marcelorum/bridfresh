#!/usr/bin/env node
// ============================================================
//  monitor_cookies.js — Cookie inspector for session expiry research
//
//  Connects to running headless Chrome on port 9222 via CDP,
//  dumps session-related cookies every N seconds.
//  Run while keepdash.sh is active.
//
//  Usage: node monitor_cookies.js [seconds_between_checks]
// ============================================================

const INTERVAL = process.argv[2] ? parseInt(process.argv[2]) : 30;
const CDP_PORT = 9222;
const fs = require('fs');
const path = require('path');

const LOGDIR = path.join(process.env.HOME, '.bridfresh-cookies');
fs.mkdirSync(LOGDIR, { recursive: true });
const LOGFILE = path.join(LOGDIR, `cookies-${new Date().toISOString().slice(0, 19).replace(/:/g, '')}.log`);

const INTERESTING = ['session', 'token', 'auth', 'sso', 'okta', 'kyndryl', 'jession', 'sid', 'state', 'nonce', 'at_', 'rt_', 'x-xsrf', 'csrf', 'connect'];

const ts = () => new Date().toISOString().replace('T', ' ').slice(0, 19);

function formatCookie(c) {
  const exp = c.expires === -1 ? 'session' : c.expires === -2 ? 'never' : new Date(c.expires * 1000).toISOString().slice(0, 19);
  return `  ${c.name.padEnd(35)} exp=${exp.padEnd(20)} domain=${c.domain.padEnd(30)} httpOnly=${c.httpOnly} secure=${c.secure}`;
}

async function dumpCookies(wsUrl) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const timeout = setTimeout(() => { ws.close(); reject(new Error('timeout')); }, 5000);

    ws.onopen = () => ws.send(JSON.stringify({ id: 1, method: 'Network.getAllCookies' }));

    ws.onmessage = (evt) => {
      const msg = JSON.parse(evt.data);
      if (msg.id === 1) {
        const cookies = (msg.result?.cookies || []).filter(c =>
          INTERESTING.some(k => c.name.toLowerCase().includes(k))
        );
        ws.send(JSON.stringify({ id: 2, method: 'Runtime.evaluate', params: { expression: 'document.URL' } }));
        ws._cookies = cookies;
        ws._total = msg.result?.cookies?.length || 0;
      }
      if (msg.id === 2) {
        clearTimeout(timeout);
        ws.close();
        resolve({ url: msg.result?.result?.value || '?', cookies: ws._cookies, total: ws._total });
      }
    };

    ws.onerror = (err) => { clearTimeout(timeout); reject(err); };
  });
}

async function run() {
  console.log('=== Cookie Monitor ===');
  console.log(`Log: ${LOGFILE}`);
  console.log(`Interval: ${INTERVAL}s\n`);

  try { await fetch(`http://localhost:${CDP_PORT}/json/version`); } catch {
    console.error(`ERROR: Chrome not running on :${CDP_PORT}. Start keepdash.sh first.`);
    process.exit(1);
  }

  const pages = await (await fetch(`http://localhost:${CDP_PORT}/json/list`)).json();
  const page = pages.find(p => p.type === 'page');
  if (!page) { console.error('ERROR: no page tab found.'); process.exit(1); }

  console.log(`Page: ${page.title || page.url}`);
  console.log('---\n');

  const start = Date.now();
  let n = 0;

  const check = async () => {
    n++;
    const elapsed = Math.round((Date.now() - start) / 1000);
    try {
      const { url, cookies, total } = await dumpCookies(page.webSocketDebuggerUrl);
      const line = `[${ts()}] #${n} (+${elapsed}s) | ${cookies.length}/${total} session cookies | ${url}`;
      console.log(line);
      fs.appendFileSync(LOGFILE, [
        '='.repeat(60), line, '-'.repeat(60),
        ...cookies.map(formatCookie), ''
      ].join('\n') + '\n');
    } catch (err) {
      const msg = `[${ts()}] #${n} ERROR: ${err.message}`;
      console.log(msg);
      fs.appendFileSync(LOGFILE, msg + '\n');
    }
  };

  await check();
  setInterval(check, INTERVAL * 1000);

  process.on('SIGINT', () => { console.log(`\nStopped. Log: ${LOGFILE}`); process.exit(0); });
  process.on('SIGTERM', () => process.exit(0));
}

run();
