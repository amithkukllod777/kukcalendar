# Bug Report — Kuk Calendar

All bugs below are **code-verified** (static evidence). Runtime reproduction is marked `NOT TESTED` where a device is required. Severity: Blocker > Critical > Major > Minor > Cosmetic.

---
## SEC-1 — Auth token stored in plaintext SharedPreferences
- **Module:** Auth / storage · **Severity:** Critical · **Priority:** P0
- **Preconditions:** User signed in.
- **Steps:** Sign in → token persisted via `SharedPreferences` key `kc_token`.
- **Expected:** Session token stored in Android Keystore-backed secure storage.
- **Actual:** Stored in plaintext app-prefs XML — `lib/cal_sync.dart:38-47`, cleared only on logout (`:56`).
- **Evidence:** `cal_sync.dart:46 await p.setString('kc_token', _token!);`
- **Root cause:** `shared_preferences` used for the bearer token instead of `flutter_secure_storage`.
- **Fix:** Move `kc_token` to `flutter_secure_storage` (Keystore/StrongBox). Keep non-secret prefs (`kc_company`, `kc_user`) as-is.
- **Regression risk:** Low-Med (migration of existing stored token on upgrade — read old key once, move, delete).

## DATA-1 — logout() does not clear local events → cross-account data leak
- **Module:** Auth / DB · **Severity:** Critical · **Priority:** P0
- **Preconditions:** Shared device; user A signed in with un-synced ("dirty") local events.
- **Steps:** User A creates events offline → logs out → user B signs in → sync runs.
- **Expected:** Logout wipes local personal data; B never sees or re-syncs A's events.
- **Actual:** `logout()` clears only the three prefs keys; the sqflite `calendar_events`/`calendar_tasks` tables are untouched — `lib/cal_sync.dart:51-59`. A's dirty events push into B's workspace on next `syncNow` (`clientKey` upsert, `cal_sync.dart` `syncNow`).
- **Evidence:** No `deleteDatabase`/`DELETE FROM` in `logout()`; grep confirms no local-wipe call anywhere.
- **Root cause:** Local store is device-global, not user-scoped; logout has no data-reset.
- **Fix:** On logout (and on login when the account differs from the last), clear/replace the local event + task tables (or namespace the DB by user id). Add a "last synced account" guard before pushing dirty rows.
- **Regression risk:** Med — must not delete un-synced data for the *same* returning user; gate on account identity.

## REL-1 — Play Store AAB is unsigned/debug
- **Module:** Release · **Severity:** Blocker (for Play) · **Priority:** P0
- **Evidence:** Published release asset `KukCalendar-PlayStore-r24-UNSIGNED-debug.aab`; CI `build.yml` signs only when `ANDROID_*` keystore secrets are present.
- **Expected:** A release-signed `.aab` uploadable to Play.
- **Actual:** Debug-signed/unsigned bundle — Play rejects it.
- **Fix:** Run `keystore.yml` to mint the upload keystore; add the 4 `ANDROID_*` secrets; re-run build → signed AAB.
- **Regression risk:** Low.

## DATA-2 — No DB migration system (version pinned to 1, ALTER errors swallowed)
- **Module:** DB · **Severity:** Major · **Priority:** P1
- **Evidence:** `lib/db.dart:23 openDatabase(path, version: 1)` (no `onUpgrade`); `lib/db_calendar.dart:117-118` runs `ALTER TABLE … ADD COLUMN` inside `catch (_) {/* already exists */}` — every error (not just "column exists") is silently ignored.
- **Actual:** Schema evolves by best-effort ALTERs with all failures masked → drift, and a genuinely failed migration is invisible.
- **Fix:** Introduce a real `onUpgrade` with a monotonic `version` and explicit per-version steps; stop blanket-swallowing ALTER errors (only ignore the specific "duplicate column" case).
- **Regression risk:** Med — must reconcile the current implicit schema into v1→v2 baseline carefully.

## SYNC-1 — Custom calendars' metadata does not sync
- **Module:** Sync · **Severity:** Major · **Priority:** P1
- **Evidence:** `cal_sync.dart` pull/push payloads carry event fields incl. `category` name, but **no** `calendar_lists` colour/visibility/sort fields; those live only in the local `calendar_lists` table (`db_calendar.dart`).
- **Actual:** On a second device, custom calendar structure/colours are not restored — only event category names.
- **Fix:** Add a `calendars.pull/push` contract (or extend the calendar sync) for list metadata.
- **Regression risk:** Low (additive).

## ARCH-1 — Tasks are a local-only engine (duplicates KukTask)
- **Module:** Tasks · **Severity:** Major · **Priority:** P1
- **Evidence:** `calendar_tasks` sqflite table + `calendar_tasks_screen.dart`; no sync references. Kuklabs mandate: personal apps should share one Task source (KukTask), not each own a task DB.
- **Fix:** Replace the local task engine with a read-only overlay of KukTask due-dates via a shared endpoint; remove the local `calendar_tasks` write path.
- **Regression risk:** Med (data-model change; migrate any existing local tasks).

## NOTIF-1 — Reminders scheduled only 30 days / 48 alarms ahead
- **Module:** Notifications · **Severity:** Major · **Priority:** P2
- **Evidence:** `db_calendar.dart:347-348 getUpcomingReminders({days=30, max=48})`, `:402 take(max)`; `notifications.dart` reschedules only on app events (`rescheduleAll`).
- **Actual:** If the user doesn't open the app for >30 days, or has >48 upcoming reminders, later recurring reminders never get scheduled → missed alarms.
- **Fix:** Reschedule on a periodic background trigger (WorkManager/`android_alarm_manager_plus`) and/or on boot; raise/rolling-window the cap.
- **Regression risk:** Low-Med.

## NOTIF-2 — Exact alarms not runtime-prompted (may be delayed)
- **Module:** Notifications · **Severity:** Minor · **Priority:** P2
- **Evidence:** `notifications.dart` requests `POST_NOTIFICATIONS` but not `SCHEDULE_EXACT_ALARM` at runtime; on `PlatformException` it falls back to `inexactAllowWhileIdle` (`:76-89`).
- **Actual:** On some Android 12 devices reminders may fire late.
- **Fix:** For Android 12 (API 31-32) optionally route the user to the exact-alarm settings screen; `USE_EXACT_ALARM` covers 13+.

## TEST-1 — Zero automated tests
- **Module:** Quality · **Severity:** Major · **Priority:** P1
- **Evidence:** No `test/` or `integration_test/` directory; no `*_test.dart`.
- **Fix:** Add unit tests for `getUpcomingReminders` (fire-time math, all-day anchor), recurrence expansion, and sync dirty/merge; a widget smoke test for the calendar screen. See `MISSING_TESTS.md`.

## OBS-1 — No crash reporting / analytics / monitoring
- **Module:** Observability · **Severity:** Major · **Priority:** P1
- **Evidence:** No Crashlytics/Sentry/analytics dependency in `pubspec.yaml`.
- **Actual:** Production crashes and reminder-scheduling failures (all swallowed by `catch (_)`) are invisible.
- **Fix:** Add a lightweight crash reporter (e.g. Sentry Flutter) with PII scrubbing; stop silently swallowing errors in `notifications.dart`/`db_calendar.dart` without at least breadcrumb logging.

## FEAT-1 — No .ics import/export · FEAT-2 — Single reminder per event
- **Severity:** Minor · **Priority:** P3 — table-stakes gaps vs competitors (see competitive files).
