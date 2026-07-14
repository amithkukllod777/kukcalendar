# Feature Inventory — Kuk Calendar

Status legend: ✅ Implemented-working (code-verified) · 🟡 Partial · 🔴 Broken/Risky · ⚪ Missing · `NOT TESTED` = needs a device to confirm runtime behaviour.

| Module | Feature | Status | Evidence (file:line) | Notes |
|---|---|---|---|---|
| Calendar views | Month view | ✅ | `calendar_screen.dart` `_monthBody`/`_monthGrid` | Redesigned to mockup; swipe to change month. `NOT TESTED` on device. |
| Calendar views | Week / 3-day / Day (time grid) | ✅ | `calendar_screen.dart` `_TimeGrid`, `_buildBody` | |
| Calendar views | Schedule (agenda) | ✅ | `calendar_screen.dart` `_scheduleBody` | |
| Events | Create / edit / delete | ✅ | `calendar_screen.dart` `_openEventForm` | Bottom-sheet form. |
| Events | All-day vs timed | ✅ | `_openEventForm` (`allDay`, time pickers) | |
| Events | Colour + category ("calendar") | ✅ | `_openEventForm`, `_lists` | |
| Events | Recurrence (daily/weekly/monthly/yearly) | 🟡 | `db_calendar.dart` `_expandOccurrences` | Basic presets only — no custom interval / end-date / RRULE. |
| Events | Reminder + "Remind at" (all-day) | ✅ | `db_calendar.dart:347` `getUpcomingReminders`; form "Remind at" | Just added. `NOT TESTED` that alarm fires on device. |
| Search | Event search | ✅ | `calendar_screen.dart` `_EventSearchDelegate` | |
| Tasks | Local to-dos | 🔴 (arch) | `calendar_tasks_screen.dart`, `db_calendar.dart` `calendar_tasks` table | **Local-only, not synced**; duplicates KukTask (`ARCH-1`). |
| Sync | Pull/push personal events | ✅ | `cal_sync.dart` `syncNow`, `calendar.pull`/`push` | Dirty-tracking + clientKey upsert. `NOT TESTED` end-to-end. |
| Sync | Custom-calendar metadata (colour/visibility/order) | ⚪ | `cal_sync.dart` (no list fields in payload) | Only event `category` name syncs (`SYNC-1`). |
| Workspace | Shared personal workspace resolution | ✅ | `cal_sync.dart` `_ensureCompany` → `workspace.getOrCreatePersonal` | Deterministic; no `list.first` fallback. |
| Auth | Email/mobile login + register + OTP | ✅ | `cal_sync.dart`, `calendar_login_screen.dart` | Friendly-error mapping; terms gate. |
| Auth | Google SSO (deep-link) | ✅ | `google_auth.dart`, `cal_sync.dart` `googleExchange` | `kukcalendar://auth` one-time-code exchange. `NOT TESTED`. |
| Auth | Logout | 🔴 | `cal_sync.dart:51-59` | Clears token but **not local events** (`DATA-1`). |
| Notifications | OS reminder notifications | 🟡 | `notifications.dart`, `getUpcomingReminders` | Capped 30 days / 48 alarms (`NOTIF-1`); exact-alarm fallback to inexact (`NOTIF-2`). |
| Storage | Offline-first sqflite | ✅ | `db.dart`, `db_calendar.dart` | DB `version: 1`, no migrations (`DATA-2`). |
| Branding | Product icon / name / tagline | ✅ | `product_brand.dart`, `assets/icon.png` | Name consistent: "Kuk Calendar". |
| Profile | Profile / About / version page | ⚪ | — | No Profile page; version only in drawer footer. |
| Import/Export | `.ics` import/export | ⚪ | — | Not implemented (`FEAT-1`). |
| Collaboration | Shared/invite/RSVP calendars | ⚪ | — | Personal only. |
| Widgets / Wear | Home-screen widget, watch | ⚪ | — | None. |

## Critical user journeys (priority)
| Journey | Priority | Code status | Runtime |
|---|---|---|---|
| Install → sign in → land on calendar | Critical | ✅ | `NOT TESTED` |
| Create timed event → appears on grid | Critical | ✅ | `NOT TESTED` |
| Set reminder → notification fires | Critical | ✅ (logic) | `NOT TESTED` (device required) |
| Create offline → sync when online | Critical | ✅ | `NOT TESTED` |
| Google SSO sign-in | High | ✅ | `NOT TESTED` |
| Logout → sign in as different user | High | 🔴 `DATA-1` | Needs fix + test |
| Recurring event across months | Medium | 🟡 | `NOT TESTED` |
| Search events | Medium | ✅ | `NOT TESTED` |
