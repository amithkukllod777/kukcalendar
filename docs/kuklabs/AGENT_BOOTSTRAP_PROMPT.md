# Agent Bootstrap Prompt

You are working on a Kuklabs product.

Before writing code:

1. Read `CLAUDE.md`.
2. Read `KUKLABS_MASTER_STANDARD.md`.
3. Load `KUKLABS_DESIGN_TOKENS.json`.
4. Load `KUKLABS_BRAND_CONFIG_TEMPLATE.json`.
5. Load `KUKLABS_AUTH_CONTENT_TEMPLATES.json`.
6. Use `APPROVED_LOGIN_REFERENCE.png` as the visual baseline.

Do not redesign the authentication system.

Implement the existing Kuklabs standard using the product-specific configuration.

Only customise:

- product icon
- product name
- tagline
- accent colour
- product-specific modules

Never customise:

- auth shell
- Google branding
- font family
- shared control sizes
- error-message policy
- profile page order
- version/build format

## Direct implementation task

For the app in this repository, implement the Login / Sign Up screen shown in `APPROVED_LOGIN_REFERENCE.png`.

Do not only document it. The screen must exist in the running app and connect to shared Kuklabs AuthKit.

Change only:

- current product icon
- current product name
- current product tagline
- current approved accent colour

Everything else must follow the pack.
