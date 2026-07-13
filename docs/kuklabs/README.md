# Kuklabs UI/Auth Agent Pack

This pack is the **single reusable source** for all Kuklabs apps so that agents, developers, designers and AI assistants do not need to rebuild the same decisions again and again.

## What is inside

1. `KUKLABS_MASTER_STANDARD.md`
   - Full product UI, auth, profile, content and release guideline
2. `KUKLABS_DESIGN_TOKENS.json`
   - Shared design tokens and exact control sizes
3. `KUKLABS_BRAND_CONFIG_TEMPLATE.json`
   - Product configuration template for every Kuk app
4. `KUKLABS_AUTH_CONTENT_TEMPLATES.json`
   - Approved auth, profile, support and error content
5. `KUKLABS_AGENT_INSTRUCTIONS.md`
   - Ready instructions for Claude / ChatGPT / dev agents
6. `APPROVED_LOGIN_REFERENCE.png`
   - Approved login-page visual reference

## How to use

- **Do not invent a new auth UI per product**
- Reuse the same auth shell, same spacing, same typography and same content rules
- Only change:
  - product icon
  - product name
  - product tagline
  - approved accent colour
  - product-specific modules/features

## Canonical identity rule

All Kuklabs apps must use:

- One Kuklabs Account
- One AuthKit
- One shared database identity
- One shared Google Cloud/Firebase project

## Recommended workflow for any agent

1. Read `KUKLABS_AGENT_INSTRUCTIONS.md`
2. Load `KUKLABS_BRAND_CONFIG_TEMPLATE.json`
3. Load `KUKLABS_DESIGN_TOKENS.json`
4. Follow `KUKLABS_MASTER_STANDARD.md`
5. Use `KUKLABS_AUTH_CONTENT_TEMPLATES.json` for ready copy



## Repo-ready files added in v2

- `CLAUDE.md`
- `REPO_INTEGRATION_GUIDE.md`
- `DEVELOPER_HANDOFF.md`
- `AGENT_BOOTSTRAP_PROMPT.md`
- `IMPLEMENTATION_CHECKLIST.json`

Use `CLAUDE.md` directly at repository root.  
Give `AGENT_BOOTSTRAP_PROMPT.md` to any coding/design agent before work begins.

## Important clarification

The reference screen is not only for KukKeep.

It is the mandatory universal Login / Sign Up screen for whichever Kuklabs app is currently being built.

Every agent must:

1. Fill `CURRENT_PRODUCT_LOGIN_CONFIG.json`
2. Read `PRODUCT_LOGIN_SCREEN_EXECUTION_PROMPT.md`
3. Implement the screen inside the actual current app
4. Change only the product icon, name, tagline and accent colour

A documentation-only change is incomplete.

## Version placement correction in V4

The app version is never shown on Login, Sign Up, OTP, password recovery, onboarding or splash.

The authentication page ends with `Powered by Kuklabs`.

Version/build is shown only as the bottom-most muted footer in:

```text
Profile → About this app
```
