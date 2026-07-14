# UI / UX Competitor Audit — Kuk Calendar

Checked 2026-07-14. Benchmarks: Google Calendar (V), any.do (V), Samsung Calendar (I). Kuk Calendar UI is code-verified; **on-device look is `NOT TESTED`**. Recommendations are design principles, not visual imitation.

| Screen / workflow | Current (Kuk) | Competitor benchmark | Problem | User impact | Recommendation | Type |
|---|---|---|---|---|---|---|
| Add event | Bottom-sheet: title, all-day, dates, (times), colour, calendar, repeat, reminder, +Remind-at, location, notes | Google/any.do: fast quick-add + smart defaults; multiple reminders | No **natural-language quick-add**; single reminder | Slower entry; power users miss quick-add | Add a quick-add field ("Lunch 1pm tomorrow"); allow N reminders | Both |
| Reminder setup | Preset offsets + new "Remind at" for all-day | any.do: recurring/location/voice reminders | All-day reminder time was previously fixed (now fixed); still 1 reminder | Alarms usable now; still limited | Multiple reminders; clearer all-day copy | Functional |
| Month view | Light bar, dots for events, swipe months | Google: Material You, density options; agenda hybrid | No density/theme options; light only | Fine, but no dark mode | Add dark mode + a compact/comfortable toggle | Visual |
| Empty states | Present ("Nothing scheduled") | Google/any.do: actionable empty states | OK | Low | Add a CTA + illustration | Visual |
| Navigation | Drawer + Month▾ menu + swipe | Google: bottom-less, view chip; any.do: tabs | Discoverability of view-switch behind the title caret | Medium | Consider a visible view chip; keep swipe | UX |
| Onboarding | Auth shell only; no feature tour | any.do/Google: light onboarding | No first-run guidance | Medium | 2-3 slide first-run or empty-state coaching | UX |
| Localization | English only; LTR | All: multi-language incl. Hindi/Arabic-RTL | No RTL, no Hindi | **High for India/GCC** | Localize + RTL (table-stakes for target market) | Both |
| Accessibility | Not audited | Screen-reader labelled | `NOT TESTED` — verify TalkBack labels, 48dp targets, contrast, font scaling | Medium-High | Run an accessibility pass | Both |
| Trust / polish | Clean Kuklabs design system, Inter | Mature, consistent | Good foundation | — (strength) | Keep design-token discipline | — |

## Key UX gaps (ranked)
1. **Localization + RTL** (table-stakes for India + GCC) — P1.
2. **Dark mode** — expected on modern Android — P2.
3. **Quick-add + multiple reminders** — entry speed & parity — P2.
4. **Accessibility pass** (TalkBack, contrast, font scaling) — `NOT TESTED`, must verify — P2.
5. **Widget** (home-screen glanceability) — table-stakes — P1 (also in feature matrix).

Extract principles (fast entry, smart defaults, glanceability, localization) rather than copying competitor screens.
