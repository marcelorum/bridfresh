#!/usr/bin/env bash
# ============================================================
#  monitor_headers.sh — HTTP response header capture
#
#  Fetches the dashboard URL and logs ALL response headers
#  (Set-Cookie, Cache-Control, etc.) every N seconds.
#  Shows what the SERVER sends back on each request.
#
#  Run alongside monitor_cookies.js for full picture:
#    - cookies.js  → what the browser HAS stored
#    - headers.sh  → what the server SENDS each request
#
#  Usage: ./monitor_headers.sh [seconds_between_checks]
# ============================================================

set -u
INTERVAL="${1:-30}"
LOGDIR="$HOME/.bridfresh-cookies"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/headers-$(date '+%Y%m%d-%H%M%S').log"

# Dashboard URL (first from config.conf, fallback to default)
CONFIG="$HOME/LAB/DEV/bridfresh/config.conf"
DASH_URL="https://www.kyndryl.com/bridge/aiops/home"
if [[ -f "$CONFIG" ]]; then
  first_url=$(sed -n '/^[[:space:]]*URLS=(/,/^[[:space:]]*)/p' "$CONFIG" | sed '1d;$d' | sed -E 's/#.*$//; /^[[:space:]]*$/d; s/^[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/' | head -1)
  [[ -n "$first_url" ]] && DASH_URL="$first_url"
fi

echo "=== Header Monitor ==="
echo "URL: $DASH_URL"
echo "Log: $LOGFILE"
echo "Interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop."
echo ""

trap 'echo; echo "Stopped. Log: $LOGFILE"; exit 0' INT

n=0
while true; do
  n=$((n + 1))
  ts=$(date '+%Y-%m-%d %H:%M:%S')

  echo "[$ts] #$n — fetching headers..."

  # Capture ALL response headers (verbose, include redirects)
  headers=$(curl -sS -D - -o /dev/null \
    --max-time 10 \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    "$DASH_URL" 2>&1)

  # Log it
  {
    echo "========================================"
    echo "[$ts] #$n"
    echo "----------------------------------------"
    echo "$headers"
    echo ""
  } >> "$LOGFILE"

  # Print compact summary to terminal
  status=$(echo "$headers" | head -1 | tr -d '\r')
  setcookie_count=$(echo "$headers" | grep -ci 'set-cookie' || true)
  cache_ctrl=$(echo "$headers" | grep -i 'cache-control' | head -1 | tr -d '\r')
  echo "  $status | Set-Cookie: ${setcookie_count} | ${cache_ctrl:-no cache-control}"

  sleep "$INTERVAL"
done
