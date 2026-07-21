import 'package:flutter_test/flutter_test.dart';
import 'package:kukcalendar/reminder_logic.dart';

void main() {
  group('dateKey / parseCalDate', () {
    test('dateKey pads to YYYY-MM-DD', () {
      expect(dateKey(DateTime(2026, 7, 4)), '2026-07-04');
      expect(dateKey(DateTime(999, 12, 31)), '0999-12-31');
    });
    test('parseCalDate handles date-only, ISO, empty, invalid', () {
      expect(parseCalDate('2026-07-14'), DateTime(2026, 7, 14));
      expect(parseCalDate('2026-07-14T09:30:00'), DateTime(2026, 7, 14));
      final fb = DateTime(2000, 1, 2, 3, 4);
      expect(parseCalDate('', fallback: fb), DateTime(2000, 1, 2));
      expect(parseCalDate('not-a-date', fallback: fb), DateTime(2000, 1, 2));
    });
  });

  group('safeDate clamps to month end', () {
    test('Jan 31 stays; Feb 31 -> Feb 28 (non-leap)', () {
      expect(safeDate(2026, 1, 31), DateTime(2026, 1, 31));
      expect(safeDate(2026, 2, 31), DateTime(2026, 2, 28));
    });
    test('Feb 29 in a leap year', () {
      expect(safeDate(2028, 2, 31), DateTime(2028, 2, 29));
    });
  });

  group('expandOccurrences', () {
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 31);

    test('daily fills the window inclusively', () {
      final occ = expandOccurrences(DateTime(2026, 7, 1), 'daily', from, to);
      expect(occ.length, 31);
      expect(occ.first, DateTime(2026, 7, 1));
      expect(occ.last, DateTime(2026, 7, 31));
    });

    test('weekly steps by 7 days from base', () {
      final occ = expandOccurrences(DateTime(2026, 7, 2), 'weekly', from, to);
      expect(occ, [
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 9),
        DateTime(2026, 7, 16),
        DateTime(2026, 7, 23),
        DateTime(2026, 7, 30),
      ]);
    });

    test('monthly on the 31st clamps to short months', () {
      final occ = expandOccurrences(
          DateTime(2026, 1, 31), 'monthly', DateTime(2026, 1, 1), DateTime(2026, 4, 30));
      expect(occ, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28), // clamped
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30), // clamped
      ]);
    });

    test('yearly yields one per year in range', () {
      final occ = expandOccurrences(
          DateTime(2024, 7, 14), 'yearly', DateTime(2025, 1, 1), DateTime(2027, 12, 31));
      expect(occ, [DateTime(2025, 7, 14), DateTime(2026, 7, 14), DateTime(2027, 7, 14)]);
    });

    test('series starting after the window is empty', () {
      final occ = expandOccurrences(DateTime(2026, 12, 1), 'daily', from, to);
      expect(occ, isEmpty);
    });
  });

  group('custom recurrence (interval + until)', () {
    test('parseRecurrence handles presets + rich forms', () {
      expect(parseRecurrence('none').repeats, isFalse);
      expect(parseRecurrence('').repeats, isFalse);
      final w = parseRecurrence('weekly');
      expect([w.type, w.interval, w.until], ['weekly', 1, null]);
      final w2 = parseRecurrence('weekly:2');
      expect([w2.type, w2.interval, w2.until], ['weekly', 2, null]);
      final w3 = parseRecurrence('monthly:3:2026-12-31');
      expect(w3.type, 'monthly');
      expect(w3.interval, 3);
      expect(w3.until, DateTime(2026, 12, 31));
      // Bad interval clamps to >=1.
      expect(parseRecurrence('daily:0').interval, 1);
    });

    test('buildRecurrence round-trips + stays backward-compatible', () {
      expect(buildRecurrence('none', 1, null), 'none');
      expect(buildRecurrence('weekly', 1, null), 'weekly'); // compact preset
      expect(buildRecurrence('weekly', 2, null), 'weekly:2');
      expect(buildRecurrence('monthly', 3, DateTime(2026, 12, 31)),
          'monthly:3:2026-12-31');
    });

    test('every-2-weeks skips alternate weeks', () {
      final occ = expandOccurrences(DateTime(2026, 7, 2), 'weekly:2',
          DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      expect(occ, [DateTime(2026, 7, 2), DateTime(2026, 7, 16), DateTime(2026, 7, 30)]);
    });

    test('until date caps the series', () {
      final occ = expandOccurrences(DateTime(2026, 7, 1), 'daily:1:2026-07-05',
          DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      expect(occ.last, DateTime(2026, 7, 5));
      expect(occ.length, 5);
    });

    test('every-2-months from an old base aligns into the window', () {
      final occ = expandOccurrences(DateTime(2025, 1, 15), 'monthly:2',
          DateTime(2026, 7, 1), DateTime(2026, 12, 31));
      // Jan 2025 + even months → Jul, Sep, Nov 2026 land in-window.
      expect(occ, [DateTime(2026, 7, 15), DateTime(2026, 9, 15), DateTime(2026, 11, 15)]);
    });
  });

  group('reminderFireTime', () {
    final now = DateTime(2026, 7, 14, 8, 0); // 08:00
    final occ = DateTime(2026, 7, 15); // tomorrow

    test('timed event fires reminderMin before its start time', () {
      final f = reminderFireTime(
          occ: occ, startTime: '09:30', reminderMin: 10, now: now);
      expect(f, DateTime(2026, 7, 15, 9, 20));
    });

    test('all-day event with no start_time anchors to 09:00 default', () {
      final f = reminderFireTime(
          occ: occ, startTime: '', reminderMin: 10, now: now);
      expect(f, DateTime(2026, 7, 15, 8, 50)); // 09:00 - 10m
    });

    test('all-day "Remind at 15:00" + at-time-of-event fires at 15:00', () {
      final f = reminderFireTime(
          occ: occ, startTime: '15:00', reminderMin: 0, now: now);
      expect(f, DateTime(2026, 7, 15, 15, 0));
    });

    test('a moment already in the past returns null', () {
      final past = DateTime(2026, 7, 10);
      final f = reminderFireTime(
          occ: past, startTime: '09:00', reminderMin: 10, now: now);
      expect(f, isNull);
    });

    test('no reminder (reminderMin < 0) returns null', () {
      final f = reminderFireTime(
          occ: occ, startTime: '09:00', reminderMin: -1, now: now);
      expect(f, isNull);
    });
  });
}
