# Options & Customization Gap — Kuk Calendar

Checked 2026-07-14. Competitor support: Google (V) / any.do (V) / Samsung (I).

| Option | Kuk support | Competitor support | Gap | Target user | Value | Complexity | Recommendation |
|---|---|---|---|---|---|---|---|
| Theme / dark mode | Missing (light only) | ✅ all | Missing | all | High | M | Add dark mode (design tokens already exist) |
| Language | Missing (en) | ✅ all | Missing | India/GCC | High | L | Localize (Hindi, Arabic-RTL) |
| Week-start day (Sun/Mon/Sat) | Not exposed (Sunday hardcoded, `_startOfWeek`) | ✅ all | Too limited | GCC (Sat start) | High | S | Add a setting; default per locale |
| Default view (month/week/agenda) | Not persisted (opens month) | ✅ all | Missing | daily users | Med | S | Persist last/default view |
| Default reminder | Not configurable | ✅ Google/any.do | Missing | all | Med | S | Add default-reminder preference |
| Multiple reminders | Missing (one) | ✅ | Too limited | all | Med | M | Allow N reminders per event |
| Custom recurrence | Presets only | ✅ | Too limited | power users | Med | L | Interval/end-date/RRULE |
| Calendars: colour/visibility/order | Local only, not synced (`SYNC-1`) | ✅ synced | Missing sync | multi-device | High | L | Sync list metadata |
| Notification channel controls | Single channel | ✅ granular | Too limited | all | Low-Med | S | Per-calendar or per-type channels |
| Time format (12/24h) | Follows `_fmtTime` (12h AM/PM) | ✅ locale/setting | Too limited | GCC/EU | Low-Med | S | Respect device/locale + setting |
| First-day/date/number formats | English defaults | ✅ locale | Missing | India/GCC | Med | M | Locale-aware formatting |
| Account / profile settings | No Profile page | ✅ | Missing | all | Med | M | Add Profile → settings + About |
| Data export | None | ✅ `.ics`/Google export | Missing | privacy-conscious | Med | M | `.ics` export (also compliance) |
| Backup / restore control | Server sync only, not user-visible | 🟡 | Poorly surfaced | all | Med | M | Surface "backed up / last synced" state |

**Where fewer options is better:** Kuk Calendar's single free tier and one-account simplicity is a genuine strength — do **not** add plan-gating or complex role config for a personal calendar. Focus customization on locale/theme/defaults (high value, low complexity), not configuration depth.
