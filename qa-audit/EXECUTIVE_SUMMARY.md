# Executive Summary — Kuk Calendar QA / Security / Production-Readiness Audit

- **App:** Kuk Calendar (standalone Flutter Android app, package `com.kuklabs.calendar`), part of the Kuklabs ecosystem.
- **Audit date:** 2026-07-14
- **Auditor scope:** Source code, DB schema, sync/notification logic, CI/build config, and a code-based competitive review.
- **Method limitation (read this first):** This audit is **code-based**. Flutter/Gradle cannot be run in the audit sandbox and the production backend (`kuklabs.com`) is network-blocked, so **no finding here was exercised on a real device or live server**. Every runtime claim is labelled `NOT TESTED` with the manual procedure to confirm it. Competitor facts are labelled `INFERRED` / `NOT VERIFIED` — live competitor verification is pending (see `COMPETITOR_SELECTION.md`).

## Overall health
Kuk Calendar is a **usable MVP** with a clean, well-structured codebase and a correct offline-first architecture. Core calendar flows (views, event CRUD, recurrence, reminders, search, sync, Kuklabs SSO) are implemented. However, it is **not production-ready for a public Play Store release** because of one plaintext-token security issue, one cross-account data-isolation defect, no automated tests, no crash reporting, an unsigned Play bundle, and several data-safety gaps in sync/migrations.

## Issue counts (confirmed, code-verified)
| Severity | Count | Examples |
|---|---|---|
| Blocker (for Play release) | 1 | Play AAB is unsigned/debug (`REL-1`) |
| Critical | 2 | Plaintext auth token (`SEC-1`); cross-account local-data leak on shared device (`DATA-1`) |
| Major | 6 | No DB migrations (`DATA-2`), custom-calendar metadata not synced (`SYNC-1`), local-only tasks engine (`ARCH-1`), reminder 30-day/48-alarm cap (`NOTIF-1`), zero tests (`TEST-1`), no crash reporting/analytics (`OBS-1`) |
| Minor | 3 | Exact-alarm not runtime-prompted (`NOTIF-2`); no `.ics` import/export (`FEAT-1`); no multiple-reminders-per-event (`FEAT-2`) |
| Cosmetic | — | Deferred to on-device UI pass |

## Top critical risks
1. **`SEC-1` — Auth Bearer token stored in plaintext `SharedPreferences`** (`lib/cal_sync.dart:38-47`). Any process with app-data access (rooted device, ADB backup, malware) can read the session token.
2. **`DATA-1` — `logout()` does not clear the local event database** (`lib/cal_sync.dart:51-59`). On a shared device, user A's locally-cached events survive user B's login and user A's un-synced ("dirty") events push into **user B's** workspace on the next sync — a privacy leak and data-integrity bug.
3. **`REL-1` — Play Store bundle is unsigned/debug** (`KukCalendar-PlayStore-*-UNSIGNED-debug.aab`). Cannot be published to Google Play until signed via `keystore.yml` + the four `ANDROID_*` secrets.
4. **`DATA-2` — No database migration system** (`lib/db.dart:23` pins `version: 1`; `lib/db_calendar.dart:117-118` swallows every `ALTER TABLE` error). Future schema changes risk silent failure and data drift.

## Recommended release decision
- **Public Play Store launch: `NO-GO`** until `REL-1`, `SEC-1`, `DATA-1`, `OBS-1`, and `TEST-1` (smoke coverage) are resolved.
- **Closed beta via sideloaded APK: `CONDITIONAL GO`** — acceptable after `SEC-1` and `DATA-1` are fixed and a real-device smoke test (install → sign in → create event → reminder fires → sync round-trip) passes. Everything else can follow in fast iterations.

See `REMEDIATION_PLAN.md` for the ordered fix list and `PRODUCTION_READINESS_CHECKLIST.md` for the full pass/fail matrix.
