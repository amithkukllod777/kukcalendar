import 'package:device_calendar/device_calendar.dart';

/// Reads the phone's SYSTEM calendars (Google, Samsung, Outlook, …) READ-ONLY
/// and returns events shaped like the calendar screen's overlay maps.
///
/// This is how Google's Gmail-parsed events — e.g. an auto-created train/flight
/// booking — appear inside Kuk Calendar with NO email access: the OS calendar
/// already holds them (Google created them from Gmail), and we simply mirror the
/// device calendar as a read-only layer, exactly like the KukTask overlay. All
/// plugin use is isolated here so a platform without a calendar provider (or a
/// denied permission) degrades gracefully to an empty layer.
class DeviceCalendarOverlay {
  DeviceCalendarOverlay._();
  static final DeviceCalendarOverlay instance = DeviceCalendarOverlay._();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  /// Ask for (or confirm) READ calendar permission. Returns true if granted.
  Future<bool> ensurePermission() async {
    try {
      var res = await _plugin.hasPermissions();
      if (res.isSuccess && res.data == true) return true;
      res = await _plugin.requestPermissions();
      return res.isSuccess && res.data == true;
    } catch (_) {
      return false; // plugin unavailable / platform without calendars
    }
  }

  /// Every event across all device calendars within [start, end], mapped to the
  /// read-only overlay row shape the calendar screen renders.
  Future<List<Map<String, dynamic>>> loadEvents(DateTime start, DateTime end) async {
    final out = <Map<String, dynamic>>[];
    try {
      final calsRes = await _plugin.retrieveCalendars();
      final cals = calsRes.data;
      if (cals == null) return out;
      for (final cal in cals) {
        final id = cal.id;
        if (id == null) continue;
        final res = await _plugin.retrieveEvents(
          id,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        final events = res.data;
        if (events == null) continue;
        for (final ev in events) {
          final s = ev.start;
          if (s == null) continue;
          final local = s.toLocal();
          final allDay = ev.allDay == true;
          final e = ev.end?.toLocal();
          out.add({
            'title': (ev.title == null || ev.title!.trim().isEmpty)
                ? '(no title)'
                : ev.title!.trim(),
            'date': DateTime(local.year, local.month, local.day),
            'endDate': e != null ? DateTime(e.year, e.month, e.day) : null,
            'time': allDay ? null : _hhmm(local),
            'endTime': (!allDay && e != null) ? _hhmm(e) : null,
            'allDay': allDay,
            'color': 'cyan',
            'source': 'device',
            'editable': false, // read-only mirror — never written back
            'category': (cal.name == null || cal.name!.isEmpty)
                ? 'Phone calendar'
                : cal.name,
            'location': ev.location,
          });
        }
      }
    } catch (_) {
      // best-effort: return whatever we gathered (usually empty) on any error.
    }
    return out;
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
