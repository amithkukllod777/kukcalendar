# Missing Tests — Kuk Calendar (prioritized by risk)

No tests exist today. Recommended additions, highest-risk first. Pure-Dart logic (reminders, recurrence, sync-merge) is unit-testable without a device and should come first.

## P0 — pure-logic unit tests (no device needed)
1. **`getUpcomingReminders` fire-time math** (`db_calendar.dart:347`)
   - timed event: fires at `start − reminderMin`; past reminders skipped.
   - **all-day anchor**: uses `start_time` clock (default 09:00) — the just-fixed behaviour; assert an all-day event with "Remind at 15:00" + "At time of event" fires at 15:00.
   - `reminderMin < 0` → no reminder; `max`/`days` window respected.
2. **Recurrence expansion** (`_expandOccurrences`) — daily/weekly/monthly/yearly across month/year boundaries; count within `[from,to]`.
3. **Sync merge / dirty tracking** (`cal_sync.dart`, `db_calendar.dart`) — dirty rows push once, `clientKey`→`cloudId` mapping applied, deletes propagate, pulled rows upsert without dup.

## P0 — regression tests for the two Critical bugs
4. **`DATA-1`**: after `logout()`, local `calendar_events`/`calendar_tasks` are empty (or namespaced) and a subsequent different-account login does not push the prior user's rows.
5. **`SEC-1`**: token is written via secure storage, not readable from `SharedPreferences`.

## P1 — widget / integration
6. Calendar screen **widget smoke test**: renders month grid, opens event form, saves an event (mock DB).
7. **Integration (device/emulator)**: create event → reminder scheduled (verify via plugin's `pendingNotificationRequests`).
8. Auth: friendly-error mapping returns no raw server text for representative error inputs (`AuthMessages.friendly`).

## Tooling to add
- `flutter_test` (already transitively available), `test/` dir, and a CI step `flutter test` in `.github/workflows/build.yml` (currently only `flutter build` runs — add `flutter test` as a gate).
- Consider `flutter analyze --fatal-infos` in CI to catch regressions early (note: would surface existing lints first).
