# Security Audit — Kuk Calendar

Date: 2026-07-14 · Method: static code review (no dynamic/pentest run). OWASP Mobile Top 10 (M-series) referenced where applicable.

## Findings (by severity)
| ID | Finding | Severity | Component | OWASP | Evidence |
|---|---|---|---|---|---|
| SEC-1 | Auth Bearer token in plaintext `SharedPreferences` | Critical | Storage | M9 Insecure Data Storage | `cal_sync.dart:38-47` |
| DATA-1 | Local personal data not cleared on logout → cross-account leak | Critical | Auth/DB | M9 / broken access control | `cal_sync.dart:51-59` |
| SEC-2 | Deep-link `kukcalendar://auth` one-time-code interception risk | Major | Deep links | M1 Improper Platform Usage | `google_auth.dart`, `build.yml` intent-filter |
| SEC-3 | Errors swallowed app-wide (`catch (_)`) hides security failures | Minor | Reliability | — | `cal_sync.dart:111`, `notifications.dart`, `db_calendar.dart` |

## Detail
### SEC-1 — Insecure token storage (Critical)
Bearer session token persisted at `kc_token` via `shared_preferences` (`cal_sync.dart:46`). Readable via ADB backup (if `allowBackup` true), rooted-device file access, or malware with the app's data dir. **Remediation:** `flutter_secure_storage` (Android Keystore). Also verify `android:allowBackup="false"` and `android:extractNativeLibs` in the injected manifest (`build.yml`).
**Attack scenario:** attacker with physical/root access extracts `kc_token` → replays as `Authorization: Bearer` against `kuklabs.com` to access the victim's calendar/account until token expiry.

### DATA-1 — Broken data isolation on shared device (Critical)
`logout()` (`cal_sync.dart:51-59`) removes only prefs keys; the sqflite event/task tables persist. Next user's sync pushes the prior user's **dirty** rows into the new account (clientKey upsert). **Remediation:** clear or user-namespace the local DB on logout and on account-change at login; guard dirty-push by "last synced account id".

### SEC-2 — Deep-link callback (Major, needs device verification)
The Google SSO flow returns to `kukcalendar://auth?code=…`. Custom-scheme deep links can be registered by other apps → a malicious app could receive the one-time code. `NOT TESTED` whether the intent-filter is `exported` and whether the code is strictly single-use/short-TTL server-side. **Remediation:** prefer Android App Links (verified https) over a custom scheme, ensure the code is single-use + short-lived (server side already issues one-time codes — confirm TTL), and PKCE if not already applied.

## PASS / not-an-issue (verified)
| Check | Result | Evidence |
|---|---|---|
| Hardcoded secrets / API keys in `lib/` + `android/` | ✅ PASS (none found) | repo grep for `api_key`/`secret`/`Bearer <literal>`/`AIza`/`sk_live` → clean |
| Cleartext HTTP | ✅ PASS | base URL `https://kuklabs.com` (`cal_sync.dart:18`); no `http://` in app code |
| Raw server text leaked to UI | ✅ PASS | all errors routed via `AuthMessages.friendly()` (`calendar_login_screen.dart:69`) |
| Password policy | ✅ PASS (basic) | ≥8 chars + letter + digit (`calendar_login_screen.dart:76-77`) |
| Terms/consent gate at signup | ✅ PASS | `_acceptedTerms` (`calendar_login_screen.dart:36`) |
| SQL injection (local sqflite) | ✅ PASS | parameterized `db.query(..., whereArgs)`; no string-concatenated SQL with user input observed |
| Tenant isolation of synced data | ✅ PASS (server-side) | sync uses `companyProcedure` + deterministic personal workspace; server owns scoping |

## Manual verification still required (`NOT TESTED`)
- ADB backup extraction of `kc_token` (confirm `allowBackup`).
- Deep-link interception PoC on a device with a second app registering `kukcalendar://`.
- Token expiry / refresh behaviour and server-side one-time-code TTL.
- TLS: certificate pinning (currently none — acceptable for MVP, note for later).

No secrets or exploit payloads are included in this report by design.
