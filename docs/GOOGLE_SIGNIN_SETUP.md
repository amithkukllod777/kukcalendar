# Enabling "Continue with Google" (owner setup — ~5 minutes)

The Google button on the Kuk Calendar login screen is **code-complete and
verified end-to-end** — app (`google_auth.dart` → `/api/auth/google/start` →
`kukcalendar://auth` deep link → `/app-exchange`) and server
(`kukbook-erp/server/googleAuth.ts`). It **self-hides** until the server has
Google OAuth credentials, because Google Sign-In cannot work without an OAuth
client registered in **your** Google Cloud project. That registration + the two
secrets are the only remaining step, and only the owner can do them (their
Google account + AWS). No app or server code change is needed.

## Step 1 — Create the OAuth client (Google Cloud Console)
1. Go to <https://console.cloud.google.com/> → your Kuklabs project (the same
   project used for the app's other Google services).
2. **APIs & Services → OAuth consent screen**: ensure it's configured
   (External, app name "Kuklabs"/"Kuk Calendar", support email). Add the scopes
   `openid`, `email`, `profile` (these are the only scopes the flow requests).
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**:
   - Application type: **Web application** (the flow runs server-side; the phone
     opens the web flow in the browser).
   - **Authorized redirect URI** — add exactly:
     ```
     https://www.kuklabs.com/api/auth/google/callback
     ```
     (The server derives the redirect URI from the request host. The app now
     targets the canonical `www` host, so this is the byte-exact value; add the
     apex `https://kuklabs.com/api/auth/google/callback` too if you ever point
     the app back at the apex.)
   - Create → copy the **Client ID** and **Client secret**.

## Step 2 — Set the two secrets on AWS
Set these as environment variables on the production server (same place as
`DATABASE_URL`, `JWT_SECRET`, …) and restart:
```
GOOGLE_CLIENT_ID=<the client id>
GOOGLE_CLIENT_SECRET=<the client secret>
```
That's it. `GET /api/auth/google/status` immediately returns `{ "enabled": true }`,
so the app shows the button and the web `/login` Google option activates too —
**no new APK build required for the button to appear** (it's a live server
toggle; the app already ships the button and only reveals it when status says
enabled).

## Step 3 — Verify
- `curl https://www.kuklabs.com/api/auth/google/status` → `{"enabled":true}`.
- Open the app → the "Continue with Google" button appears on Login/Sign Up.
- Tap it → browser opens the Google account picker → returns to the app signed in.

## Notes
- Same One-Kuklabs-Account: a Google sign-in with an email that already has an
  email+password account **links into that same account** (verified email only)
  — no duplicate users.
- The app trades the one-time deep-link code for a Bearer token via **POST**
  `/api/auth/google/app-exchange` (hardened — the code never rides in a URL).
- Nothing here is India/product-specific — this is Platform Core universal
  sign-in.
