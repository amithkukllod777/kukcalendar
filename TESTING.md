# Kuk Calendar — Testing

## Status (2026-07-02)

| Check | Result |
|---|---|
| GitHub Actions APK build (`build.yml`, main) | ✅ green — run #1, `Move Kuk Calendar to repo root` |
| `latest` release published with `KukCalendar-r1.apk` | ✅ 2026-07-02 20:33 UTC |
| Server sync contract (full protocol, 38 automated checks) | ✅ all passing |
| On-device smoke test (physical phone) | ⬜ pending — checklist below |

## Automated sync-contract test

The full client↔server sync protocol used by `lib/cal_sync.dart` is covered by
an automated harness in the kukbook-erp repo:
`scripts/kukcal-sync-smoke.mjs` (run against a local kukbook-erp server — see
the header comment for setup). It replays the app's exact wire format (tRPC
batch envelope, Bearer token, `x-company-id` header) and verifies:

1. Sign-up (`auth.directRegister` → OTP → `auth.verifyOtp`) and
   sign-in (`auth.directLogin`) return a usable Bearer token.
2. Company bootstrap for a brand-new account (`company.list` empty →
   `company.create` with `signupModule: 'calendar'` → workspace id), matching
   `CalSync._ensureCompany`.
3. `calendar.push` returns a `clientKey → cloudId` mapping.
4. `calendar.pull` round-trips **every** event field: title, description,
   start/end date, start/end time, allDay, color, location, category,
   recurrence, reminderMin.
5. Re-pushing the same `clientKey` **upserts** (same cloudId, no duplicate).
6. Recurring (`weekly`) and all-day events round-trip; all-day events come
   back with empty times.
7. Tombstone deletes (`deleted: true`) remove the server row (mapping returns
   `cloudId: null`) and the event no longer appears in `pull`.
8. Auth guards: `pull` without a token is rejected; `pull` with a foreign
   `x-company-id` is rejected (tenant isolation).
9. A second device signing in to the same account finds the existing
   workspace (no duplicate company) and pulls the surviving events.

Latest run: **38 passed, 0 failed** against the calendar router in
kukbook-erp `server/routers.ts` (the same code deployed on kuklabs.com).

## On-device smoke checklist (manual)

Install `KukCalendar-r1.apk` from
<https://github.com/amithkukllod777/kukcalendar/releases/tag/latest>
(enable "install from unknown sources" if prompted), then:

1. **Offline first**: open the app with no account — month view renders,
   today is highlighted.
2. **Create event**: tap a day → add a timed event with a location and a
   30-min reminder → appears on the day; edit it → change persists; kill and
   reopen the app → still there (sqflite).
3. **Recurring**: create a weekly event → future weeks show occurrences.
4. **Tasks**: add a task, mark complete, delete (tasks are local-only for
   now — no cloud sync yet).
5. **Sign in**: menu → Sign in with a KukLabs account (same login as
   KukTask/KukKeep). A brand-new account should silently get a workspace.
6. **Sync up**: tap Sync → status shows "Synced"; the event created in step 2
   appears on the kuklabs.com web calendar (`/calendar`) under the same
   account.
7. **Sync down**: create an event on the web calendar → Sync on the phone →
   it appears in the app.
8. **Cross-device delete**: delete the step-2 event on the phone → Sync →
   it disappears from the web calendar (tombstone propagation).
9. **Session expiry**: after a 401 the app should return to the signed-out
   state with "Session expired — please sign in again."

## Known gaps (next work items)

- Reminders are stored but **no OS notification fires yet**
  (`flutter_local_notifications` + `timezone` pending).
- Tasks are local-only (events sync; tasks don't).
- Play-Store signing: the build workflow now produces an AAB and signs it
  when the `ANDROID_*` keystore secrets are set (generate the keystore once
  via the "Kuk Calendar keystore" workflow — see its header for the exact
  secret names). Until the secrets are added, APK/AAB stay debug-signed.
- No drag-to-move/resize, swipe navigation, advanced recurrence
  (every-N / end-date / edit-this-vs-all), or timezone support.
