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
docs/kuklabs/CURRENT_PRODUCT_LOGIN_CONFIG.json   — this app's filled-in values
docs/kuklabs/APP_VERSION_DISPLAY_POLICY.md       — version NEVER on auth screens
```

Pack version: V4 (`docs/kuklabs/KUKLABS_DESIGN_TOKENS.json` → `"version": "4.0.0"`). V2→V4 are
JSON-schema reorganizations of the same control sizes (58px controls, 420 maxWidth, 24 welcome,
etc.) — `lib/kuklabs/auth_tokens.dart` already matches; no token/content values changed. V4 adds
one binding policy: version/build must never render on Login/Sign Up/OTP/Forgot/Reset/Welcome —
only in Profile → About this app (today: the drawer footer in `calendar_screen.dart`, since
there is no Profile page yet). `calendar_login_screen.dart` already complies (it has never shown
a version string).

## 🚫 GOLDEN RULE — NO automatic APK/AAB builds (owner mandate 2026-07-24)
**Never build, trigger, or dispatch an Android APK or AAB (app bundle) build unless
the owner explicitly asks for a build in that moment.**
- `build.yml` is **`workflow_dispatch`-only (manual)**. Do **NOT** add
  `push` / `pull_request` / `schedule` triggers to it or to any app-build workflow.
- The agent must **never** run/dispatch a build workflow on its own (no
  `actions` run-trigger for builds).
- Pushing code / opening PRs is fine — but it must **not** kick off an APK/AAB
  build. Before pushing, confirm no build workflow will auto-run.
- The owner starts releases manually from the Actions tab when they want one.

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
- Login and Sign Up share one shell. Version is **never** shown on any auth screen — see
  `docs/kuklabs/APP_VERSION_DISPLAY_POLICY.md`; format `Version x.y.z (Build n)` applies only
  to Profile → About this app / the drawer footer.

## Only these may change per product (from `lib/kuklabs/product_brand.dart`)
- product icon · product name · tagline · approved accent colour · product-
  specific modules/workflows.

## App map
- `lib/screens/calendar_screen.dart` — the calendar (offline-first, sqflite).
- `lib/screens/calendar_login_screen.dart` — the Kuklabs auth shell.
- `lib/cal_sync.dart` — tRPC-over-HTTP client for the shared backend
  (`auth.*`, `workspace.getOrCreatePersonal` for the deterministic personal
  workspace — NOT `company.list`/`list.first`; `calendar.pull`/`push` +
  `pullLists`/`pushLists`; `tasks.myUpcoming` read overlay; Google `/status` +
  `/app-exchange`). The auth token is kept in `flutter_secure_storage` (Keystore).
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
