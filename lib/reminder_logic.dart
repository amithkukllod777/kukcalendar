/// Pure, dependency-free calendar logic (no DB, no Flutter bindings) so it can
/// be unit-tested headless with `flutter test`. `db_calendar.dart` delegates to
/// these; keeping the maths here locks the behaviour (esp. the all-day reminder
/// anchor) against regressions. See `test/reminder_logic_test.dart`.
library;

/// 'YYYY-MM-DD' key for a date.
String dateKey(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

/// Parse a stored date string ('YYYY-MM-DD' or full ISO) to a date-only value.
/// Falls back to "today" on empty/invalid input.
DateTime parseCalDate(Object? raw, {DateTime? fallback}) {
  final s = (raw as String?)?.trim() ?? '';
  final fb = fallback ?? DateTime.now();
  if (s.isEmpty) return DateTime(fb.year, fb.month, fb.day);
  try {
    final d = DateTime.parse(s.length >= 10 ? s.substring(0, 10) : s);
    return DateTime(d.year, d.month, d.day);
  } catch (_) {
    return DateTime(fb.year, fb.month, fb.day);
  }
}

/// Clamp (y, m, day) to a valid date — e.g. asking for the 31st of a 30-day
/// month yields the 30th, so a monthly-on-the-31st series lands on month-end.
DateTime safeDate(int y, int m, int day) {
  final lastDay = DateTime(y, m + 1, 0).day; // day 0 of next month = last day
  return DateTime(y, m, day > lastDay ? lastDay : day);
}

/// Occurrence dates (date-only) of a recurring event within [from]‥[to].
/// `rec` is one of 'none'/''/'daily'/'weekly'/'monthly'/'yearly'.
List<DateTime> expandOccurrences(
    DateTime base, String rec, DateTime from, DateTime to) {
  base = DateTime(base.year, base.month, base.day);
  from = DateTime(from.year, from.month, from.day);
  to = DateTime(to.year, to.month, to.day);
  final out = <DateTime>[];
  if (base.isAfter(to)) return out; // series begins after the window
  var guard = 0;
  switch (rec) {
    case 'daily':
      {
        var dd = from.isAfter(base) ? from : base;
        while (!dd.isAfter(to) && guard++ < 1000) {
          out.add(dd);
          dd = dd.add(const Duration(days: 1));
        }
      }
    case 'weekly':
      {
        var dd = base;
        while (dd.isBefore(from) && guard++ < 6000) {
          dd = dd.add(const Duration(days: 7));
        }
        while (!dd.isAfter(to) && guard++ < 1000) {
          if (!dd.isBefore(base)) out.add(dd);
          dd = dd.add(const Duration(days: 7));
        }
      }
    case 'monthly':
      {
        var y = base.year, m = base.month;
        final day = base.day;
        while (guard++ < 3000) {
          final occ = safeDate(y, m, day);
          if (occ.isAfter(to)) break;
          if (!occ.isBefore(from) && !occ.isBefore(base)) out.add(occ);
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
      }
    case 'yearly':
      {
        var y = base.year;
        final m = base.month, day = base.day;
        while (guard++ < 500) {
          final occ = safeDate(y, m, day);
          if (occ.isAfter(to)) break;
          if (!occ.isBefore(from) && !occ.isBefore(base)) out.add(occ);
          y++;
        }
      }
  }
  return out;
}

/// The instant a reminder should fire for one occurrence on [occ], or `null`
/// when there is no reminder ([reminderMin] < 0) or the moment is already past
/// (not after [now]).
///
/// Anchor: both timed AND all-day events anchor to [startTime]. All-day events
/// store the user-chosen "Remind at" clock there (default 09:00 when unset), so
/// an all-day reminder fires at a moment the user controls rather than a fixed
/// hard-coded time.
DateTime? reminderFireTime({
  required DateTime occ,
  String? startTime,
  required int reminderMin,
  required DateTime now,
}) {
  if (reminderMin < 0) return null;
  var hh = 9, mm = 0; // default 09:00 anchor
  final st = startTime ?? '';
  if (st.contains(':')) {
    final p = st.split(':');
    hh = int.tryParse(p[0]) ?? 9;
    mm = int.tryParse(p[1]) ?? 0;
  }
  final start = DateTime(occ.year, occ.month, occ.day, hh, mm);
  final fireAt = start.subtract(Duration(minutes: reminderMin));
  return fireAt.isAfter(now) ? fireAt : null;
}
