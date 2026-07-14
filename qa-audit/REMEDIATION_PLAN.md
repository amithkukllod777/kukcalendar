# Remediation Plan — Kuk Calendar

Complexity: S (<0.5d) · M (1-2d) · L (3-5d) · XL (>1wk). Owner: App = Flutter client, BE = kukbook-erp backend, DevOps = CI/release.

## Immediate — before ANY public/beta release
| ID | Action | Pri | Owner | Cx | Depends on | Verify |
|---|---|---|---|---|---|---|
| SEC-1 | Move `kc_token` to `flutter_secure_storage` (Keystore); migrate existing token on upgrade | P0 | App | M | — | Token not readable in app-prefs XML / ADB backup |
| DATA-1 | Clear (or user-namespace) local event+task DB on logout & on account-change login; guard dirty-push by last-synced account id | P0 | App | M | — | A's events gone after B logs in; no cross-account push (device test) |
| REL-1 | Run `keystore.yml`, add 4 `ANDROID_*` secrets → signed release AAB | P0 | DevOps | S | — | AAB shows release signature; Play upload accepted |
| SMOKE | Real-device smoke: install → sign in (email + Google) → create timed & all-day event → reminder fires → offline create → sync round-trip | P0 | QA | M | SEC-1, DATA-1 | All pass on ≥1 physical device |

## Short term — next sprint
| ID | Action | Pri | Owner | Cx |
|---|---|---|---|---|
| OBS-1 | Add crash reporting (Sentry Flutter) + stop blind `catch (_)` swallowing (add breadcrumbs) | P1 | App | M |
| TEST-1 | Unit tests: `getUpcomingReminders` fire-time/all-day anchor, recurrence expansion, sync dirty/merge; 1 widget smoke test | P1 | App | M |
| DATA-2 | Real sqflite `onUpgrade` with monotonic version; narrow ALTER catch to duplicate-column only | P1 | App | M |
| SYNC-1 | Sync `calendar_lists` metadata (colour/visibility/order) via a `calendars.pull/push` contract | P1 | App+BE | L |
| NOTIF-1 | Periodic reschedule (WorkManager/alarm-manager) + on-boot; widen reminder window/cap | P1 | App | M |

## Medium term
| ID | Action | Pri | Cx |
|---|---|---|---|
| ARCH-1 | Replace local task engine with read-only KukTask due-date overlay (shared endpoint); remove `calendar_tasks` write path | P1 | L |
| L10N | Localization: Hindi + Arabic (RTL) — table-stakes for India/GCC | P1 | L |
| FEAT | Custom recurrence (interval/end/RRULE), multiple reminders per event | P2 | L |
| FEAT | Home-screen widget; dark mode | P2 | L |
| FEAT | `.ics` import/export | P2 | M |
| PROFILE | Profile → About page (version row per policy) | P2 | S |

## Long term / tech debt
- External account sync (Google/Outlook import) — large; evaluate vs ecosystem-only positioning.
- Shared/collaborative calendars + invites/RSVP.
- iOS/web clients (ecosystem parity).
- Certificate pinning; Play Data Safety form; store listing assets.

## Sequencing note
`DATA-1` and `SEC-1` are the two gates for even a closed beta. `REL-1` gates Play only. Everything in "Immediate" should land before wider distribution; the rest can ship in fast iterations without re-blocking release.
