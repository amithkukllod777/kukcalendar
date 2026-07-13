# Product Login Screen Execution Prompt

Implement the mandatory Kuklabs universal authentication screen in the app currently contained in this repository.

Visual reference:

```text
APPROVED_LOGIN_REFERENCE.png
```

Current product values:

```text
Product name: {PRODUCT_NAME}
Product ID: {PRODUCT_ID}
Product icon: {PRODUCT_ICON_PATH}
Approved tagline: {PRODUCT_TAGLINE}
Approved accent colour: {PRODUCT_ACCENT}
```

Required work:

1. Build or refactor the actual Login / Sign Up screen in this app.
2. Match the approved reference's hierarchy, proportions, spacing and component sizes.
3. Use the current app's real product icon.
4. Display `Welcome to`, the current product name and its approved tagline.
5. Keep Login and Sign Up inside one shared shell.
6. Include mobile/email, country-code smart detection, password, Forgot Password, primary action, official Google button, Terms, Privacy and Powered by Kuklabs.
7. Connect it to shared Kuklabs AuthKit.
8. Never create separate auth, users, sessions, database or Firebase infrastructure.
9. Never show raw JSON/framework errors.
10. Use the approved one-screen layout with safe scrolling fallback.

The visual reference is not KukKeep-only. It is mandatory for this app and every Kuklabs app.

Only product icon, product name, tagline and approved accent colour may change.

## Version rule

- Do not display app version, build number, release channel or commit hash on Login / Sign Up.
- The auth screen ends with `Powered by Kuklabs`.
- Display version only at the bottom of `Profile → About this app`.
