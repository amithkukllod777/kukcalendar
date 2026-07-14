# Test Coverage Matrix — Kuk Calendar

**Current automated coverage: 0%** — no `test/` or `integration_test/` directory exists. All rows below are `NOT TESTED` (no automated suite) unless noted; "Manual" = must be exercised by hand on a device.

| Feature | Smoke | Functional | Negative | Boundary | Security | Regression | UI/UX | Automated | Result |
|---|---|---|---|---|---|---|---|---|---|
| App launch / calendar loads | Manual | — | — | — | — | — | Manual | ❌ none | NOT TESTED |
| Event create/edit/delete | Manual | Manual | Manual | Manual | — | Manual | Manual | ❌ none | NOT TESTED |
| Reminder fire-time (`getUpcomingReminders`) | — | **should be unit** | should be unit | should be unit (all-day 09:00, past-skip) | — | — | — | ❌ none | NOT TESTED |
| Recurrence expansion | — | **should be unit** | — | should be unit (month boundaries) | — | — | — | ❌ none | NOT TESTED |
| Sync pull/push (dirty/merge/clientKey) | Manual | **should be unit+integration** | Manual (offline) | — | Manual | Manual | — | ❌ none | NOT TESTED |
| Login / register / OTP | Manual | Manual | Manual (bad creds) | — | Manual | — | Manual | ❌ none | NOT TESTED |
| Google SSO deep-link | Manual | — | — | — | Manual (intercept) | — | — | ❌ none | NOT TESTED |
| Logout data isolation (`DATA-1`) | Manual | **must add regression test** | — | — | **Manual (critical)** | — | — | ❌ none | NOT TESTED |
| Token storage (`SEC-1`) | — | — | — | — | Manual (ADB backup) | — | — | ❌ none | NOT TESTED |
| Offline create → online sync | Manual | Manual | Manual | — | — | Manual | — | ❌ none | NOT TESTED |

**Runnable now:** `flutter analyze` (static) and `flutter build` (CI, green). No behavioural tests exist, so no behavioural PASS can be claimed. See `MISSING_TESTS.md`.
