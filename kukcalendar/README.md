# Kuk Calendar

A standalone personal calendar for Android (Flutter), part of the KukLabs suite.
Offline-first, with **optional** cloud sync using your KukLabs account — the same
login as **KukTask** and **KukKeep** — via the shared backend at `kuklabs.com`.

## Features
- Month / Week / 3-day / Day / **Schedule** views (Google-Calendar-style timeline)
- Create / edit / delete events (all-day or timed, colour, location, notes)
- Multiple **calendars/categories** with colour on/off toggles
- **Recurring** events (daily / weekly / monthly / yearly)
- **Tasks** (to-dos with due dates)
- Search, navigation drawer, current-time line
- **Optional login + cloud sync** across Kuk Calendar / KukTask / KukKeep

## Architecture
- **Local:** SQLite (`sqflite`) — `lib/db.dart` + `lib/db_calendar.dart`.
- **Sync:** tRPC-over-HTTP (`dio`) to `kuklabs.com` — `lib/cal_sync.dart`
  (`auth.directLogin` for the shared account; `calendar.pull` / `calendar.push`
  for events; token in `SharedPreferences`, `kc_` namespace).
- The backend (accounts, DB, calendar sync endpoints) is the **shared KukLabs
  platform** — this app does not run its own server.

## Build (CI)
`.github/workflows/build.yml` builds the APK on push to `main` or via **Run
workflow**. The native `android/` project is generated in CI by `flutter create`
(the repo keeps only `pubspec.yaml` + `lib/`). Output → the **`latest`** release
as `KukCalendar.apk` (package `com.kuklabs.calendar`).

## Build (local)
```bash
flutter create --org com.kuklabs --project-name kukcalendar --platforms=android .
flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```
