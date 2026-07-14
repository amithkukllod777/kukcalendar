# Performance Audit — Kuk Calendar

**No runtime profiling was possible** (no device/emulator in the audit sandbox). All rows are code-based observations (`ASSUMPTION`) or `NOT TESTED`. Measured numbers must come from a device profiling pass (DevTools / `flutter run --profile`).

| Metric | Observed | Expected threshold | Status | Note / bottleneck | Recommendation |
|---|---|---|---|---|---|
| Cold start | — | <2s mid-range | NOT TESTED | Flutter + sqflite open + `_load`/`_loadLists`/`_initSync` in `initState` | Defer sync off the first frame; profile |
| Month view render | — | 60fps | NOT TESTED | 6×7 grid rebuilt per `setState`; `_byDay` recomputed | Memoize `_byDay`; `const` cells where possible |
| Event query | — | <50ms | ASSUMPTION ok | sqflite indexed by date range | Verify index on `start_date` |
| `getUpcomingReminders` | — | <100ms | ASSUMPTION ok | scans events, expands recurrence over 30d, caps 48 | Fine at MVP scale; watch with large recurring sets |
| Sync round-trip | — | network-bound | NOT TESTED | dio, 20s connect / 30s receive timeouts (`cal_sync.dart:24-25`) | OK; add retry/backoff on transient failure |
| Memory / battery | — | — | NOT TESTED | reminders reschedule is cancel-all + re-add (signature-guarded, cheap) | Profile alarm churn on real device |
| Unnecessary rebuilds | ⚠️ | — | ASSUMPTION | whole screen `setState` on selection/nav | Split into smaller widgets; `ValueListenable` for selection |

## Code-level efficiency notes (VERIFIED from source)
- `rescheduleAll()` uses a signature check to no-op when nothing changed (`notifications.dart:57-60`) — good.
- Reminder scheduling is bounded (48 alarms) — protects against alarm-slot exhaustion but causes the coverage gap `NOT-1`.
- No pagination on event lists (agenda/schedule) — acceptable at personal scale; revisit if a user has thousands of events.

**Action:** run one `flutter run --profile` session on a mid-range device, capture cold-start, month-scroll jank, and sync timing; replace the `NOT TESTED` rows with real numbers.
