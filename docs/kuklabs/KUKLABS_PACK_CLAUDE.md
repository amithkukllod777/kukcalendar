# CLAUDE.md — Kuklabs Product Repository Rules

## MANDATORY IMPLEMENTATION FOR THE APP CURRENTLY BEING BUILT

This is not only a reference document.

**The app you are currently building or modifying must actually implement the approved Kuklabs Login / Sign Up screen.**

Use `APPROVED_LOGIN_REFERENCE.png` as the visual baseline.

For the current app:

1. Replace the sample product icon with the current app's real product icon.
2. Replace `KukKeep` with the current app's official product name.
3. Replace the sample tagline with the current app's approved tagline.
4. Replace the blue accent only with the current app's approved accent colour.
5. Keep the same page structure, block order, spacing, typography, control sizes, radii, Google button, legal placement, `Powered by Kuklabs`, smart identity-input behaviour, error handling and responsive behaviour.

Do not treat this pack as optional inspiration.

If the app has no login screen, create it.
If it already has a different login screen, refactor it.
A documentation-only change is incomplete.


## Mandatory Kuklabs platform rule

This repository is part of the Kuklabs ecosystem.

Before changing authentication, branding, navigation, profile, app version display, content or shared UI, read:

```text
docs/kuklabs/KUKLABS_MASTER_STANDARD.md
docs/kuklabs/KUKLABS_AGENT_INSTRUCTIONS.md
docs/kuklabs/KUKLABS_DESIGN_TOKENS.json
docs/kuklabs/KUKLABS_AUTH_CONTENT_TEMPLATES.json
```

The canonical identity and infrastructure rules are defined by the Kuklabs platform standard.

## Non-negotiable rules

- Use one Kuklabs Account.
- Use the shared AuthKit contract.
- Do not create a separate user/password/session system.
- Do not create a separate database identity.
- Do not create a separate Google Cloud/Firebase project.
- Use Inter as the primary app font.
- Use shared design tokens.
- Use the approved universal login/signup screen.
- Use the official Google multicolour G logo.
- Never show raw JSON, stack traces or framework errors to users.
- Use the approved friendly error catalogue.
- Keep Login and Sign Up in the same authentication shell.
- Use the shared Profile and About structure.
- Show app version as `Version x.y.z (Build n)`.

## Product-specific values

Only these values may be changed:

```text
product icon
product name
product tagline
approved product accent colour
product-specific modules and workflows
```

These must come from:

```text
src/config/productBrand.ts
```

## Before implementing UI

1. Load `productBrand`.
2. Load `KUKLABS_DESIGN_TOKENS.json`.
3. Reuse approved content from `KUKLABS_AUTH_CONTENT_TEMPLATES.json`.
4. Compare authentication UI against `APPROVED_LOGIN_REFERENCE.png`.
5. Do not invent new sizes or content when a token/template already exists.

## Pull-request rejection conditions

Reject any change that:

- forks auth UI without approval
- changes global typography
- uses arbitrary colours
- changes shared block sizes
- replaces product icon with Kuklabs corporate logo
- recolours the Google logo
- shows raw backend errors
- creates duplicate account logic
- removes accessibility labels
- breaks one-screen auth behaviour on standard phones
- hides legal links or Powered by Kuklabs
