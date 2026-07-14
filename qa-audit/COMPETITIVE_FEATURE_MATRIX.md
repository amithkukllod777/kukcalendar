# Competitive Feature Matrix — Kuk Calendar

Checked 2026-07-14. Availability: ✅ full · 🟡 partial · ⚪ missing. Competitor evidence label in parentheses (V=Verified, I=Inferred, NV=Not Verified). C1 Google Calendar, C2 any.do, C3 Samsung Calendar.

| Capability | Kuk Calendar | C1 Google | C2 any.do | C3 Samsung | Gap type | Priority |
|---|---|---|---|---|---|---|
| Month/Week/Day/Agenda views | ✅ | ✅ (V) | ✅ (V) | ✅ (I) | — (parity) | — |
| Event CRUD | ✅ | ✅ (V) | ✅ (V) | ✅ (I) | — | — |
| Recurrence (custom interval/end/RRULE) | 🟡 presets only | ✅ (V) | ✅ custom (V) | ✅ (I) | Table-Stakes | P1 |
| Multiple reminders per event | ⚪ (one) | ✅ (V) | ✅ (V) | ✅ (I) | Table-Stakes | P2 |
| Location-based reminders | ⚪ | 🟡 (I) | ✅ Premium (V) | ⚪ (I) | Differentiation (low) | P3 |
| Natural-language quick-add | ⚪ | ✅ (I) | ✅ (V) | 🟡 (NV) | Competitive-Disadvantage | P2 |
| Tasks / to-dos | 🟡 local-only | ✅ Google Tasks on calendar (V) | ✅ core (V) | 🟡 (I) | Competitive-Disadvantage (`ARCH-1`) | P1 |
| Shared / collaborative calendars | ⚪ | ✅ (V) | ✅ sharing (V) | 🟡 (I) | Table-Stakes | P1 |
| Invites / RSVP | ⚪ | ✅ (V) | 🟡 (NV) | ✅ (I) | Competitive-Disadvantage | P2 |
| External account sync (Google/Outlook) | ⚪ (Kuklabs only) | ✅ (V) | ✅ (V) | ✅ (I) | Table-Stakes | P1 |
| `.ics` import/export | ⚪ | ✅ (I) | 🟡 (NV) | ✅ (I) | Table-Stakes | P2 |
| Home-screen widget | ⚪ | ✅ (V) | ✅ (I) | ✅ (I) | Table-Stakes | P1 |
| Wear/watch app | ⚪ | ✅ (I) | 🟡 (NV) | ✅ (I) | Low-Value (for now) | P3 |
| Offline use | ✅ (offline-first) | 🟡 view/create, sync later (V) | 🟡 (NV) | ✅ (I) | **Strength / parity+** | — |
| Cross-device restore of custom calendars | ⚪ (`SYNC-1`) | ✅ (V) | ✅ (V) | ✅ (I) | Competitive-Disadvantage | P1 |
| Localization (Hindi / Arabic-RTL) | ⚪ (en only) | ✅ (I) | ✅ (I) | ✅ (I) | Table-Stakes (for India+GCC) | P1 |
| Themes / dark mode | 🟡 light only | ✅ Material You (V) | ✅ Premium themes (V) | ✅ (I) | Table-Stakes | P2 |
| Ecosystem single-account (KukBook/Task/Keep) | ✅ | ⚪ | 🟡 own suite (V) | ⚪ | **Differentiation** | protect |
| Free with no paywall | ✅ | ✅ (V) | 🟡 freemium, $2.99/mo Premium (V) | ✅ (I) | **Strength** | protect |
| Crash reporting/analytics maturity | ⚪ (`OBS-1`) | ✅ (I) | ✅ (I) | ✅ (I) | (internal) | P1 |

## Gap classification summary
- **Table-Stakes gaps (must close for credibility):** custom recurrence, shared calendars, external account sync, widget, `.ics`, localization (Hindi/Arabic), dark mode, multi-device custom-calendar restore.
- **Competitive-Disadvantage:** local-only tasks vs on-calendar tasks; no quick-add; no invites/RSVP.
- **Differentiation to protect/expand:** one Kuklabs account across the suite; genuinely offline-first; free/no paywall; India+GCC focus.
- **Low-Value / Do-not-rush:** wear app, location reminders.

## Sources
Google: [Play listing](https://play.google.com/store/apps/details?id=com.google.android.calendar&hl=en_US), [offline help](https://support.google.com/calendar/answer/1340696). any.do: [Play](https://play.google.com/store/apps/details?id=com.anydo&hl=en_US), [pricing](https://www.any.do/pricing). Samsung rows: INFERRED (dedicated verification pending).
