# Production-Readiness Checklist — Kuk Calendar

Date: 2026-07-14. Status: PASS / FAIL / NOT VERIFIED (needs device or backend access).

| # | Requirement | Status | Evidence / Note |
|---|---|---|---|
| 1 | App builds (APK + AAB) | ✅ PASS | CI `build.yml` green; r24 published |
| 2 | No blocker/critical bugs | ❌ FAIL | `SEC-1`, `DATA-1` (Critical); `REL-1` (Blocker for Play) |
| 3 | Release-signed Play AAB | ❌ FAIL | asset is `…-UNSIGNED-debug.aab`; needs `keystore.yml` + `ANDROID_*` secrets |
| 4 | Debug mode disabled in release | ✅ PASS (likely) | built with `flutter build … --release`; `NOT VERIFIED` that `kDebugMode` paths are absent |
| 5 | No test/dev credentials in code | ✅ PASS | repo grep clean |
| 6 | Secrets secured (none hardcoded) | ✅ PASS | no keys/tokens in `lib/`/`android/` |
| 7 | Secure token storage | ❌ FAIL | plaintext `SharedPreferences` (`SEC-1`) |
| 8 | Production API configured | ✅ PASS | `https://kuklabs.com` (`cal_sync.dart:18`); no staging switch (acceptable) |
| 9 | Crash reporting / monitoring | ❌ FAIL | none (`OBS-1`) |
| 10 | Analytics for critical funnels | ❌ FAIL | none present |
| 11 | Automated tests | ❌ FAIL | zero (`TEST-1`) |
| 12 | DB migrations safe | ⚠️ FAIL | `version:1`, swallowed ALTERs (`DATA-2`) |
| 13 | App version correct & displayed | ✅ PASS | `pubspec 1.0.0+1`; `app_info.dart`; shown in drawer footer (never on auth screens per policy) |
| 14 | Legal pages reachable | ✅ PASS | terms/privacy/support URLs in `product_brand.dart` (kuklabs.com) — `NOT VERIFIED` those pages exist live |
| 15 | Store metadata / listing | ⛔ NOT VERIFIED | no Play listing assets in repo |
| 16 | Release notes | ⛔ NOT VERIFIED | GitHub release body only |
| 17 | Data-safety / permissions justified | ⚠️ PARTIAL | POST_NOTIFICATIONS, exact-alarm, boot, internet — all justified; Play Data Safety form not prepared |
| 18 | Rollback plan | ⛔ NOT VERIFIED | app: reinstall prior APK; backend: separate repo |
| 19 | Backup & restore tested | ⛔ NOT VERIFIED | local sqflite only; cloud copy = server sync (not restore-tested) |
| 20 | Support contact works | ⚠️ PARTIAL | support URL present; `NOT VERIFIED` live |
| 21 | Crash-free core journey on device | ⛔ NOT TESTED | requires physical device smoke test |
| 22 | Reminder actually fires on device | ⛔ NOT TESTED | logic verified; device confirmation pending |
| 23 | Offline→online sync round-trip | ⛔ NOT TESTED | logic verified; device confirmation pending |

## Verdict
**Public Play launch: NO-GO** (items 2, 3, 7, 9, 11). **Closed beta (sideload APK): CONDITIONAL GO** after items 7 (`SEC-1`) and 2/`DATA-1` are fixed and items 21-23 pass a real-device smoke test.
