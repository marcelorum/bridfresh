# Review Follow-ups — keepdash.sh

Recorded after the bounded 4R review of commit `44ae777` (feat: dedicated invisible browser keepalive for Kyndryl dashboard). All findings are non-blocking (WARNING / SUGGESTION) and remain open.

Review context: lineage `review-be3c10b139f9a019`, target `sha256:be3c10b139f9a019...`, risk HIGH → full 4R set. Verdict per lens: CLEAR.

---

## Open follow-ups

### 1. CDP port 9222 exposed without auth token
- **Lens:** review-risk (R1)
- **Severity:** WARNING
- **Location:** `keepdash.sh:130-142`
- **Claim:** The dedicated Chrome runs with `--remote-debugging-port=9222` and the `.dash-profile/` SSO session. DevTools Protocol is an unauthenticated HTTP/WS API on localhost: any local process (or a malicious page via localhost rebinding) can list, close, and navigate tabs in the logged-in browser.
- **Proof refs:** `keepdash.sh:130-142` (`--remote-debugging-port="$PORT"`), `keepdash.sh:176-181` (the script itself does PUT `/json/close` and `/json/new` without a key).
- **Possible fix:** pass `--remote-debugging-auth-token` (Chrome supports it) or restrict the debugging socket, then add the token to the curl calls.

### 2. Fixed port 9222 with no identity check
- **Lens:** review-risk (R1)
- **Severity:** WARNING
- **Location:** `keepdash.sh:126-181`
- **Claim:** `dash_is_up` only checks that *something* answers on 9222. If another instance/app already occupies the port, the script closes and navigates the other process's tabs.
- **Proof refs:** `keepdash.sh:126` (`curl http://localhost:$PORT/json/version`), `keepdash.sh:177` (`/json/close/${id}`).
- **Possible fix:** verify the `/json/version` `Browser` identity / user-data-dir before acting, or use a random port recorded in a state file.

### 3. Volatile and world-readable log
- **Lens:** review-risk (R1)
- **Severity:** WARNING
- **Location:** `keepdash.sh:142`
- **Claim:** Chrome stderr is redirected to `/tmp/keepdash-chrome.log` (world-readable by umask) and may include session/auth error info.
- **Proof refs:** `keepdash.sh:142` (`>/tmp/keepdash-chrome.log 2>&1`).
- **Possible fix:** use a per-user path (e.g. `$HOME/Library/Logs/`) and tighter permissions.

### 4. Silent refresh failure leaves zero tabs
- **Lens:** review-resilience (R4)
- **Severity:** WARNING
- **Location:** `keepdash.sh:181` (+175-178)
- **Claim:** `dash_refresh` closes all tabs, then runs `/json/new` with errors sent to `/dev/null`; the unconditional echo still prints "refresca >" as success. If the CDP call fails, the browser is left with zero tabs for the whole interval with no user notice.
- **Proof refs:** `keepdash.sh:175-178` + `keepdash.sh:181` (`curl ... >/dev/null 2>&1`) + `keepdash.sh:184` (unconditional echo).
- **Possible fix:** check the curl exit code / response and print a real error line.

### 5. Auth check silently disabled when CDP is down
- **Lens:** review-resilience (R4)
- **Severity:** WARNING
- **Location:** `keepdash.sh:164`
- **Claim:** `dash_needs_auth` greps the CDP `/json/list`; if the CDP dies mid-cycle, curl fails, grep finds nothing, and the function returns false — the loop keeps refreshing, session-expiry detection and reads stay inactive without any warning or reboot attempt.
- **Proof refs:** `keepdash.sh:163-165`, `keepdash.sh:241` and `:254` consume the result as false.
- **Possible fix:** distinguish "CDP unavailable" from "no login page" and attempt `dash_boot` or alert.

### 6. Post-refresh auth check is a no-op (detection latency)
- **Lens:** review-reliability (R3)
- **Severity:** WARNING
- **Location:** `keepdash.sh:251-258`
- **Claim:** Right after `/json/new`, Chrome lists the tab with the requested dashboard URL, and the redirect to `login.kyndryl.com` happens asynchronously afterward. The immediate `dash_needs_auth` therefore always returns "no auth", so expiry is only actually detected at the start of the next loop iteration — up to one `INTERVAL` of latency.
- **Proof refs:** `keepdash.sh:172-184`, `keepdash.sh:253` (immediate check), `keepdash.sh:241` (loop-start check after `sleep 260`).
- **Possible fix:** re-check after a short delay, or poll the CDP target's effective URL a few times.

### 7. Substring auth detection (false positives/negatives)
- **Lens:** review-reliability (R3)
- **Severity:** WARNING
- **Location:** `keepdash.sh:161-165`
- **Claim:** `grep -qE 'login\.|okta'` matches substrings across every target's title+url in `/json/list`, case-sensitive. A dashboard URL/title containing "login" or "okta" (e.g. base64 in `?ou=` or `filters=`) can abort the keep-alive with a spurious "session expired"; an SSO page whose host lacks those substrings can be missed.
- **Proof refs:** `keepdash.sh:163-164` (grep), `keepdash.sh:224-231` / `:241-258` (decision points).
- **Possible fix:** anchor the match to the expected SSO host(s) instead of substring matching.

### 8. First-boot race: 3 s wait may be too short
- **Lens:** review-reliability (R3)
- **Severity:** WARNING
- **Location:** `keepdash.sh:223-224`
- **Claim:** `dash_boot` waits until `/json/version` responds, then only `sleep 3` before the auth check. On an unauthenticated profile, the SSO redirect round-trip can exceed 3 s, producing a premature "authenticated" verdict; the dead session is not detected until a later iteration.
- **Proof refs:** `keepdash.sh:143-152` (boot loop), `keepdash.sh:224-231` (single-snapshot decision).
- **Possible fix:** poll for the final effective URL / title instead of a fixed sleep.

### 9. Trap only handles SIGINT
- **Lens:** review-risk (R1) / review-resilience (R4)
- **Severity:** SUGGESTION
- **Location:** `keepdash.sh:238`
- **Claim:** The trap covers Ctrl+C (SIGINT); SIGTERM (session close, `kill`, shutdown) leaves the headless Chrome with the SSO session running in the background.
- **Proof refs:** `keepdash.sh:238` (`trap '... dash_stop ...' INT`).
- **Possible fix:** add SIGTERM to the trap.

### 10. No pre-check for the Chrome binary
- **Lens:** review-resilience (R4)
- **Severity:** SUGGESTION
- **Location:** `keepdash.sh:138`
- **Claim:** Without Chrome installed, `dash_boot` burns the full 20 s boot loop before erroring.
- **Proof refs:** `keepdash.sh:138-151`.
- **Possible fix:** `[[ -x "$CHROME" ]] || exit 1` before booting.

### 11. Header flags help omits long flags
- **Lens:** review-readability (R2)
- **Severity:** SUGGESTION
- **Location:** `keepdash.sh:25-28`
- **Claim:** The header "Flags:" block lists only `-t`, `-u`, `-h` while the script accepts `--login/--once/--stop/--show` (documented in "Uso" and in MANUAL).
- **Proof refs:** `keepdash.sh:25-28` vs `keepdash.sh:19-23`; `docs/MANUAL.md` flags table.
- **Possible fix:** add the long flags to the header help block.

### 12. Hard-coded `sed -n '10,32p'` in usage()
- **Lens:** review-readability (R2)
- **Severity:** SUGGESTION
- **Location:** `keepdash.sh:50`
- **Claim:** `usage()` prints a frozen line range coupled to the header height; editing the banner silently desyncs the help.
- **Proof refs:** `keepdash.sh:50`.
- **Possible fix:** delimit the help block with markers and print between them.

### 13. Typo in header comment
- **Lens:** review-readability (R2)
- **Severity:** SUGGESTION
- **Location:** `keepdash.sh:5-6`
- **Claim:** "over la pestana real" should read "sobre la pestaña real".
- **Possible fix:** trivial text fix.

---

## Closed / addressed during review

- `config.example.conf` described legacy keys (`URLS`, `CHROME/SAFARI/FIREFOX`, `RELOAD_MODE`) that `keepdash.sh` does not read — rewritten to `INTERVAL`-only before the review was frozen. (Found by docs writer, fixed pre-review.)
- The MANUAL sentence about "other keys carried over from legacy" became misleading after that rewrite; MANUAL now reflects the `INTERVAL`-only config.
