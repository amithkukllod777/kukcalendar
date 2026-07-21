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

/// A parsed recurrence rule. The stored/synced `recurrence` field is a compact
/// string that is backward-compatible with the old presets:
///   'none' / '' / 'daily' / 'weekly' / 'monthly' / 'yearly'   → interval 1, no end
///   'weekly:2' / 'monthly:3'                                   → every N, no end
///   'weekly:2:2026-12-31'                                      → every N, until date
class Recurrence {
  final String type; // none/daily/weekly/monthly/yearly
  final int interval; // every N (>= 1)
  final DateTime? until; // inclusive last date, or null for open-ended
  const Recurrence(this.type, this.interval, this.until);
  bool get repeats => type != 'none' && type.isNotEmpty;
}

Recurrence parseRecurrence(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty || s == 'none') return const Recurrence('none', 1, null);
  final parts = s.split(':');
  final type = parts[0];
  var interval = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 1) : 1;
  if (interval < 1) interval = 1;
  DateTime? until;
  if (parts.length >= 3 && parts[2].isNotEmpty) {
    try {
      final d = DateTime.parse(parts[2]);
      until = DateTime(d.year, d.month, d.day);
    } catch (_) {/* leave open-ended */}
  }
  return Recurrence(type, interval, until);
}

/// Compose the compact recurrence string. Emits the plain preset when there is
/// nothing custom, so old readers stay compatible.
String buildRecurrence(String type, int interval, DateTime? until) {
  if (type == 'none' || type.isEmpty) return 'none';
  final i = interval < 1 ? 1 : interval;
  if (i == 1 && until == null) return type;
  return '$type:$i:${until == null ? '' : dateKey(until)}';
}

/// Occurrence dates (date-only) of a recurring event within [from]‥[to],
/// honouring the "every N" interval and an optional until date.
List<DateTime> expandOccurrences(
    DateTime base, String rec, DateTime from, DateTime to) {
  final rule = parseRecurrence(rec);
  base = DateTime(base.year, base.month, base.day);
  from = DateTime(from.year, from.month, from.day);
  var end = DateTime(to.year, to.month, to.day);
  if (rule.until != null && rule.until!.isBefore(end)) end = rule.until!;
  final out = <DateTime>[];
  if (!rule.repeats || base.isAfter(end)) return out;
  final step = rule.interval;
  var guard = 0;
  switch (rule.type) {
    case 'daily':
    case 'weekly':
      {
        final stepDays = (rule.type == 'weekly' ? 7 : 1) * step;
        var dd = base;
        if (dd.isBefore(from)) {
          // Jump forward to the first on-cadence occurrence >= from.
          final k = (from.difference(dd).inDays + stepDays - 1) ~/ stepDays;
          dd = base.add(Duration(days: k * stepDays));
        }
        while (!dd.isAfter(end) && guard++ < 4000) {
          out.add(dd);
          dd = dd.add(Duration(days: stepDays));
        }
      }
    case 'monthly':
      {
        var y = base.year, m = base.month;
        final day = base.day;
        while (guard++ < 4000) {
          final occ = safeDate(y, m, day);
          if (occ.isAfter(end)) break;
          if (!occ.isBefore(from) && !occ.isBefore(base)) out.add(occ);
          m += step;
          while (m > 12) {
            m -= 12;
            y++;
          }
        }
      }
    case 'yearly':
      {
        var y = base.year;
        final m = base.month, day = base.day;
        while (guard++ < 2000) {
          final occ = safeDate(y, m, day);
          if (occ.isAfter(end)) break;
          if (!occ.isBefore(from) && !occ.isBefore(base)) out.add(occ);
          y += step;
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
