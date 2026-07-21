/// iCalendar (.ics / RFC 5545) generate + parse — pure, dependency-free so it is
/// unit-tested headless. Kuk Calendar uses this to export events to a standard
/// .ics file (share/backup) and import events from one (migrate from Google /
/// Samsung / Outlook). The UI wiring (share sheet / file picker) lives elsewhere;
/// this module is just the correctness-critical text <-> event conversion.
library;

/// A minimal calendar event shape shared by export/import (date-only + optional
/// HH:mm times, matching the local store's fields).
class IcsEvent {
  final String title;
  final String? description;
  final String? location;
  final DateTime startDate; // date-only
  final DateTime? endDate;
  final String? startTime; // 'HH:mm' or null (all-day)
  final String? endTime;
  final bool allDay;
  const IcsEvent({
    required this.title,
    this.description,
    this.location,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.allDay = true,
  });
}

String _pad(int n, [int w = 2]) => n.toString().padLeft(w, '0');
String _dateStamp(DateTime d) => '${_pad(d.year, 4)}${_pad(d.month)}${_pad(d.day)}';

// RFC 5545 TEXT escaping: backslash, semicolon, comma, newline.
String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('\n', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;');
String _unesc(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '\\' && i + 1 < s.length) {
      final n = s[i + 1];
      b.write(n == 'n' || n == 'N' ? '\n' : n);
      i++;
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

int? _min(String? hm) {
  if (hm == null || !hm.contains(':')) return null;
  final p = hm.split(':');
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// Serialize events to a complete VCALENDAR document. All-day events use
/// DATE values (DTEND is exclusive per RFC 5545); timed events use local
/// DATE-TIME (floating, no TZID) so they import at the same wall-clock time.
String generateIcs(List<IcsEvent> events, {DateTime? stamp}) {
  final now = stamp ?? DateTime(2020, 1, 1);
  final dtstamp =
      '${_dateStamp(now)}T${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Kuklabs//Kuk Calendar//EN',
    'CALSCALE:GREGORIAN',
  ];
  var seq = 0;
  for (final e in events) {
    final start = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
    final end = e.endDate == null
        ? start
        : DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day);
    lines.add('BEGIN:VEVENT');
    lines.add('UID:${_dateStamp(start)}-${seq++}@kukcalendar.kuklabs.com');
    lines.add('DTSTAMP:${dtstamp}Z');
    if (e.allDay || e.startTime == null) {
      lines.add('DTSTART;VALUE=DATE:${_dateStamp(start)}');
      // DTEND is exclusive → day after the last day.
      lines.add('DTEND;VALUE=DATE:${_dateStamp(end.add(const Duration(days: 1)))}');
    } else {
      final sm = _min(e.startTime) ?? 0;
      final em = _min(e.endTime) ?? (sm + 60);
      String dt(DateTime d, int m) =>
          '${_dateStamp(d)}T${_pad(m ~/ 60)}${_pad(m % 60)}00';
      lines.add('DTSTART:${dt(start, sm)}');
      lines.add('DTEND:${dt(end, em)}');
    }
    lines.add('SUMMARY:${_esc(e.title)}');
    if ((e.description ?? '').isNotEmpty) {
      lines.add('DESCRIPTION:${_esc(e.description!)}');
    }
    if ((e.location ?? '').isNotEmpty) {
      lines.add('LOCATION:${_esc(e.location!)}');
    }
    lines.add('END:VEVENT');
  }
  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

DateTime? _parseIcsDate(String v) {
  // 'YYYYMMDD' or 'YYYYMMDDTHHMMSS(Z)'
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(v);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

String? _parseIcsTime(String v) {
  final m = RegExp(r'T(\d{2})(\d{2})').firstMatch(v);
  if (m == null) return null;
  return '${m[1]}:${m[2]}';
}

/// Parse a VCALENDAR document into events. Tolerant of folded lines, unknown
/// properties, and both DATE and DATE-TIME forms.
List<IcsEvent> parseIcs(String text) {
  // Unfold: a line beginning with a space/tab continues the previous one.
  final raw = text.replaceAll('\r\n', '\n').split('\n');
  final unfolded = <String>[];
  for (final l in raw) {
    if (l.startsWith(' ') || l.startsWith('\t')) {
      if (unfolded.isNotEmpty) unfolded[unfolded.length - 1] += l.substring(1);
    } else {
      unfolded.add(l);
    }
  }
  final out = <IcsEvent>[];
  Map<String, String>? cur;
  String? curStartRaw, curEndRaw;
  bool allDay = false;
  for (final line in unfolded) {
    final t = line.trim();
    if (t == 'BEGIN:VEVENT') {
      cur = {};
      curStartRaw = curEndRaw = null;
      allDay = false;
      continue;
    }
    if (t == 'END:VEVENT') {
      if (cur != null) {
        final sd = curStartRaw == null ? null : _parseIcsDate(curStartRaw);
        if (sd != null) {
          DateTime? ed = curEndRaw == null ? null : _parseIcsDate(curEndRaw);
          if (allDay && ed != null) {
            ed = ed.subtract(const Duration(days: 1)); // DTEND exclusive → inclusive
          }
          out.add(IcsEvent(
            title: cur['SUMMARY'] ?? '(untitled)',
            description: cur['DESCRIPTION'],
            location: cur['LOCATION'],
            startDate: sd,
            endDate: ed,
            allDay: allDay,
            startTime: allDay ? null : (curStartRaw == null ? null : _parseIcsTime(curStartRaw)),
            endTime: allDay ? null : (curEndRaw == null ? null : _parseIcsTime(curEndRaw)),
          ));
        }
      }
      cur = null;
      continue;
    }
    if (cur == null) continue;
    final idx = line.indexOf(':');
    if (idx < 0) continue;
    final keyPart = line.substring(0, idx); // may carry ;VALUE=DATE etc.
    final value = line.substring(idx + 1);
    final key = keyPart.split(';')[0].toUpperCase();
    if (key == 'DTSTART') {
      curStartRaw = value.trim();
      if (keyPart.toUpperCase().contains('VALUE=DATE') && !value.contains('T')) {
        allDay = true;
      }
    } else if (key == 'DTEND') {
      curEndRaw = value.trim();
    } else if (key == 'SUMMARY' || key == 'DESCRIPTION' || key == 'LOCATION') {
      cur[key] = _unesc(value);
    }
  }
  return out;
}
