import 'package:flutter_test/flutter_test.dart';
import 'package:kukcalendar/ics.dart';

void main() {
  group('generateIcs', () {
    test('emits a well-formed VCALENDAR with a DATE all-day event', () {
      final ics = generateIcs([
        IcsEvent(title: 'Holiday', startDate: _d, allDay: true),
      ]);
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('DTSTART;VALUE=DATE:20260714'));
      // DTEND is exclusive → the next day for a single all-day event.
      expect(ics, contains('DTEND;VALUE=DATE:20260715'));
      expect(ics, contains('SUMMARY:Holiday'));
      expect(ics, contains('END:VCALENDAR'));
      expect(ics.endsWith('\r\n'), isTrue);
    });

    test('escapes RFC 5545 special chars in text', () {
      final ics = generateIcs([
        IcsEvent(
            title: 'Lunch, with; team\nback-to-back', startDate: _d),
      ]);
      expect(ics, contains(r'SUMMARY:Lunch\, with\; team\nback-to-back'));
    });

    test('timed event emits DATE-TIME DTSTART/DTEND', () {
      final ics = generateIcs([
        IcsEvent(
            title: 'Standup',
            startDate: _d,
            startTime: '09:30',
            endTime: '10:00',
            allDay: false),
      ]);
      expect(ics, contains('DTSTART:20260714T093000'));
      expect(ics, contains('DTEND:20260714T100000'));
    });
  });

  group('parseIcs round-trips generateIcs', () {
    test('all-day event survives export → import', () {
      final src = [
        IcsEvent(title: 'Trip', startDate: _d, endDate: _d2, allDay: true),
      ];
      final back = parseIcs(generateIcs(src));
      expect(back.length, 1);
      expect(back[0].title, 'Trip');
      expect(back[0].allDay, isTrue);
      expect(back[0].startDate, DateTime(2026, 7, 14));
      // DTEND exclusive (16th) is converted back to the inclusive last day (15th).
      expect(back[0].endDate, DateTime(2026, 7, 15));
    });

    test('timed event survives export → import', () {
      final src = [
        IcsEvent(
            title: 'Call',
            startDate: _d,
            startTime: '14:15',
            endTime: '15:00',
            allDay: false),
      ];
      final back = parseIcs(generateIcs(src));
      expect(back[0].allDay, isFalse);
      expect(back[0].startTime, '14:15');
      expect(back[0].endTime, '15:00');
    });

    test('escaped text + location round-trips', () {
      final src = [
        IcsEvent(
            title: 'A, B; C',
            location: 'Room; 2',
            description: 'line1\nline2',
            startDate: _d),
      ];
      final back = parseIcs(generateIcs(src));
      expect(back[0].title, 'A, B; C');
      expect(back[0].location, 'Room; 2');
      expect(back[0].description, 'line1\nline2');
    });
  });

  group('parseIcs tolerance', () {
    test('handles folded lines + unknown properties', () {
      const raw = 'BEGIN:VCALENDAR\r\n'
          'VERSION:2.0\r\n'
          'X-WR-CALNAME:Whatever\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:abc\r\n'
          'DTSTART;VALUE=DATE:20260720\r\n'
          'SUMMARY:Very long tit\r\n'
          ' le that was folded\r\n'
          'STATUS:CONFIRMED\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';
      final ev = parseIcs(raw);
      expect(ev.length, 1);
      expect(ev[0].title, 'Very long title that was folded');
      expect(ev[0].startDate, DateTime(2026, 7, 20));
      expect(ev[0].allDay, isTrue);
    });

    test('empty / non-calendar text yields no events', () {
      expect(parseIcs(''), isEmpty);
      expect(parseIcs('not a calendar'), isEmpty);
    });
  });
}

final _d = DateTime(2026, 7, 14);
final _d2 = DateTime(2026, 7, 15);
