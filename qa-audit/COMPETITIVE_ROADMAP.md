# Competitive Roadmap — Kuk Calendar

Each item: problem · evidence · user value · competitive value · dependencies · complexity · success metric.

## Immediate (this release cycle) — trust & table-stakes
1. **Week-start + default-view + default-reminder settings**
   - Problem: Sunday/12h/month hardcoded; GCC users start Sat. Evidence: `_startOfWeek` Sunday; `OPTIONS_CUSTOMIZATION_GAP`. Value: correctness for target market. Comp: parity. Deps: none. Cx: S. Metric: setting respected on device.
2. **Dark mode**
   - Problem: light-only. Evidence: `app_theme.dart` single theme. Value: expected UX. Comp: table-stakes. Cx: M. Metric: theme toggle + system-follow.
3. **Fix data-safety basics (`DATA-1`,`SEC-1`)** — prerequisite for trust; see `REMEDIATION_PLAN`.

## Next release — parity that removes objections
4. **Localization: Hindi + Arabic (RTL)**
   - Evidence: en-only strings. Value: core to India+GCC. Comp: table-stakes. Cx: L. Metric: full string coverage + RTL layout.
5. **Home-screen widget**
   - Comp: all three have it (V/I). Value: glanceability = retention. Cx: L. Metric: widget shows next events, updates on change.
6. **KukTask due-date overlay (replace local tasks, `ARCH-1`)**
   - Value: ecosystem payoff (unique). Comp: differentiation. Deps: shared endpoint (BE). Cx: L. Metric: KukTask due dates appear read-only on the calendar.
7. **Multiple reminders + custom recurrence**
   - Comp: table-stakes. Cx: L. Metric: N reminders fire; RRULE-style recurrence.

## Next quarter — differentiation
8. **Ecosystem glue: KukKeep reminders + KukBook business events overlay** on one calendar (single Kuklabs account).
   - Value: the reason to choose Kuk over Google — one account, many surfaces. Comp: **differentiation** (no competitor spans this suite). Metric: overlays toggle on/off; no duplicate engines.
9. **`.ics` import/export** — migration on-ramp from Google/Samsung. Cx: M.
10. **Shared/collaborative personal calendars** (family) — table-stakes at scale; Cx: XL.

## Long-term opportunities
- iOS + web clients (ecosystem parity); Wear tile; natural-language quick-add; external Google/Outlook import.

## Do NOT build (now)
- **Plan gating / paid tiers** for the personal calendar — free simplicity is a strength vs any.do's paywall (V). 
- **Location/voice reminders, watch app** — low value at current stage; revisit after retention basics.
- **Enterprise scheduling / meeting-poll features** — wrong segment for a personal calendar.

## Strengths to protect & expand
Offline-first (genuine, not "view-only offline" like Google) · one Kuklabs account across KukBook/Task/Keep · free/no paywall · India+GCC focus · clean Kuklabs design system. Expand via the ecosystem overlays (#6, #8) — that is the durable moat competitors cannot copy.
