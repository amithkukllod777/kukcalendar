# CLAUDE.md — Kuk Calendar (Kuklabs product repository)

Kuk Calendar is a standalone Kuklabs app. It follows the **Kuklabs universal
identity + UI/Auth standard** — the canonical source lives in `kukbook-erp`
(`KUKLABS_IDENTITY.md`) and the reusable pack is vendored here under
`docs/kuklabs/`. Read these before touching auth, branding, navigation,
profile, version display, content or shared UI:

```
docs/kuklabs/KUKLABS_MASTER_STANDARD.md
docs/kuklabs/KUKLABS_AGENT_INSTRUCTIONS.md
docs/kuklabs/KUKLABS_DESIGN_TOKENS.json
docs/kuklabs/KUKLABS_AUTH_CONTENT_TEMPLATES.json
docs/kuklabs/APPROVED_LOGIN_REFERENCE.png
```

## Non-negotiable rules
- One Kuklabs Account (shared `auth.*` on kuklabs.com); no separate user/
  password/session store, no separate DB identity, no separate Google Cloud/
  Firebase project.
- Google sign-in uses the shared **SSO deep-link flow** (`google_auth.dart` →
  `/api/auth/google/start?app=kukcalendar` → `kukcalendar://auth` → `/app-exchange`).
- **Inter** font, shared design tokens (`lib/kuklabs/auth_tokens.dart` mirrors
  `KUKLABS_DESIGN_TOKENS.json`), approved auth shell, official multi-colour
  Google "G" logo.
- Never show raw server text / JSON / stack traces — always map through
  `lib/kuklabs/auth_messages.dart` (the approved friendly catalogue).
- Login and Sign Up share one shell; version shown as `Version x.y.z (Build n)`.

## Only these may change per product (from `lib/kuklabs/product_brand.dart`)
- product icon · product name · tagline · approved accent colour · product-
  specific modules/workflows.

## App map
- `lib/screens/calendar_screen.dart` — the calendar (offline-first, sqflite).
- `lib/screens/calendar_login_screen.dart` — the Kuklabs auth shell.
- `lib/cal_sync.dart` — tRPC-over-HTTP client for the shared backend
  (`auth.*`, `calendar.pull`/`push`, `company.*`, Google `/status` + `/app-exchange`).
- `lib/google_auth.dart` — Google SSO deep-link flow + official G logo.
- `lib/notifications.dart` — event reminder OS notifications.
- `lib/kuklabs/` — vendored standard: product brand, auth tokens, auth messages.
- CI: `.github/workflows/build.yml` generates the native android/ scaffold via
  `flutter create` and injects manifest bits (notifications receivers + the
  `kukcalendar://auth` deep link); builds APK + Play Store AAB, publishes to the
  `latest` release on `main`. `keystore.yml` mints the upload keystore.

## Build note
`app_links` is pinned to `6.3.2` — 6.4.x's Gradle references `flutter.compileSdkVersion`
which the flutter-create scaffold doesn't provide, breaking `assembleRelease`.
