import 'dart:developer' as dev;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'db.dart';
import 'reminder_logic.dart' as rl;

/// True for the "duplicate column name" error SQLite raises when an additive
/// ALTER re-runs on a column that already exists — the one and only case the
/// lazy schema migration is allowed to ignore. Anything else is a real failure.
bool _isDuplicateColumn(Object e) =>
    e.toString().toLowerCase().contains('duplicate column');

// Thin delegates to the pure, unit-tested logic in reminder_logic.dart. Keeping
// these names avoids churn at the call sites below.
String _calDateKey(DateTime dt) => rl.dateKey(dt);
DateTime _calParseDate(Object? raw) => rl.parseCalDate(raw);
List<DateTime> _expandOccurrences(
        DateTime base, String rec, DateTime from, DateTime to) =>
    rl.expandOccurrences(base, rec, from, to);

/// Unified Calendar store (Google-Calendar-style). Offline-first: the
/// calendar_events table self-creates on first use so no central migration is
/// required. The calendar also overlays existing business data by date
/// (invoices due, payments, expenses, cheques, service reminders) — those are
/// read straight from their own local tables.
extension CalendarStore on AppDb {
  Future<void> _ensureCalendarTable(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS calendar_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        start_date TEXT NOT NULL,
        end_date TEXT DEFAULT '',
        start_time TEXT DEFAULT '',
        end_time TEXT DEFAULT '',
        all_day INTEGER DEFAULT 1,
        color TEXT DEFAULT 'blue',
        location TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    // Additive columns — lazy migration. Each ALTER throws "duplicate column
    // name" once the column exists, which is expected and ignored; ANY OTHER
    // failure (corruption, disk full, locked db) is surfaced as a log
    // breadcrumb instead of being silently swallowed (qa-audit DATA-2).
    for (final col in const [
      "category TEXT DEFAULT 'My calendar'",
      "recurrence TEXT DEFAULT 'none'", // none/daily/weekly/monthly/yearly
      'reminder_min INTEGER DEFAULT -1', // minutes before start; -1 = none
      'client_key TEXT', // stable per-event id for cloud sync
      'cloud_id INTEGER', // server row id once synced
      'dirty INTEGER DEFAULT 1', // 1 = needs push
      'deleted INTEGER DEFAULT 0', // 1 = tombstone (deleted, pending push)
    ]) {
      try {
        await d.execute('ALTER TABLE calendar_events ADD COLUMN $col');
      } catch (e) {
        if (!_isDuplicateColumn(e)) {
          dev.log('calendar_events ADD COLUMN failed ($col)',
              name: 'kukcal.db', error: e);
        }
      }
    }
    // Backfill a stable client_key for any pre-sync rows so they can sync.
    try {
      final missing = await d.query('calendar_events',
          columns: ['id'], where: 'client_key IS NULL');
      for (final m in missing) {
        await d.update('calendar_events', {'client_key': const Uuid().v4()},
            where: 'id = ?', whereArgs: [m['id']]);
      }
    } catch (e) {
      dev.log('client_key backfill skipped', name: 'kukcal.db', error: e);
    }
    await _ensureLists(d);
  }

  // ─── Calendars / categories (each: name, colour, visible) ─────────────────
  Future<void> _ensureLists(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS calendar_lists(
        name TEXT PRIMARY KEY,
        color TEXT NOT NULL DEFAULT 'blue',
        visible INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    final c = await d.rawQuery('SELECT COUNT(*) AS n FROM calendar_lists');
    if (((c.first['n'] as int?) ?? 0) == 0) {
      const defaults = [
        ['My calendar', 'blue'],
        ['Work', 'orange'],
        ['Family', 'green'],
        ['Personal', 'purple'],
        ['Birthdays', 'pink'],
        ['Holidays', 'teal'],
      ];
      for (var i = 0; i < defaults.length; i++) {
        await d.insert('calendar_lists', {
          'name': defaults[i][0],
          'color': defaults[i][1],
          'visible': 1,
          'sort_order': i,
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getCalendarLists() async {
    final d = await db;
    await _ensureCalendarTable(d);
    final rows =
        await d.query('calendar_lists', orderBy: 'sort_order ASC, name ASC');
    return rows
        .map((r) => <String, dynamic>{
              'name': (r['name'] as String?) ?? '',
              'color': (r['color'] as String?) ?? 'blue',
              'visible': ((r['visible'] as int?) ?? 1) == 1,
            })
        .toList();
  }

  Future<void> setListVisible(String name, bool visible) async {
    final d = await db;
    await _ensureCalendarTable(d);
    await d.update('calendar_lists', {'visible': visible ? 1 : 0},
        where: 'name = ?', whereArgs: [name]);
  }

  Future<void> addCalendarList(String name, String color) async {
    final d = await db;
    await _ensureCalendarTable(d);
    final n = name.trim();
    if (n.isEmpty) return;
    await d.insert(
      'calendar_lists',
      {'name': n, 'color': color, 'visible': 1, 'sort_order': 100},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─── Standalone events CRUD ───────────────────────────────────────────────
  Future<int> saveCalendarEvent({
    int? id,
    required String title,
    String description = '',
    required DateTime startDate,
    DateTime? endDate,
    String startTime = '',
    String endTime = '',
    bool allDay = true,
    String color = 'blue',
    String location = '',
    String category = 'My calendar',
    String recurrence = 'none',
    int reminderMin = -1,
  }) async {
    final d = await db;
    await _ensureCalendarTable(d);
    final values = <String, Object?>{
      'title': title,
      'description': description,
      'start_date': _calDateKey(startDate),
      'end_date': _calDateKey(endDate ?? startDate),
      'start_time': allDay ? '' : startTime,
      'end_time': allDay ? '' : endTime,
      'all_day': allDay ? 1 : 0,
      'color': color,
      'location': location,
      'category': category,
      'recurrence': recurrence,
      'reminder_min': reminderMin,
      'dirty': 1, // needs cloud push
    };
    if (id == null) {
      values['created_at'] = DateTime.now().toIso8601String();
      values['client_key'] = const Uuid().v4();
      values['deleted'] = 0;
      return d.insert('calendar_events', values);
    }
    await d.update('calendar_events', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> deleteCalendarEvent(int id) async {
    final d = await db;
    await _ensureCalendarTable(d);
    // If already synced to the cloud, keep a tombstone so the delete propagates;
    // otherwise remove it outright.
    final rows = await d.query('calendar_events',
        where: 'id = ?', whereArgs: [id], limit: 1);
    final synced =
        rows.isNotEmpty && (rows.first['cloud_id'] != null);
    if (synced) {
      await d.update('calendar_events', {'deleted': 1, 'dirty': 1},
          where: 'id = ?', whereArgs: [id]);
    } else {
      await d.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
    }
  }

  // ─── Cloud sync helpers (used by CalSync) ─────────────────────────────────
  /// Local rows that still need to be pushed (new/edited/deleted).
  Future<List<Map<String, dynamic>>> getDirtyEvents() async {
    final d = await db;
    await _ensureCalendarTable(d);
    final rows = await d.query('calendar_events', where: 'dirty = 1');
    return rows.map((r) {
      final allDay = ((r['all_day'] as int?) ?? 1) == 1;
      return <String, dynamic>{
        'clientKey': (r['client_key'] as String?) ?? '',
        'deleted': ((r['deleted'] as int?) ?? 0) == 1,
        'title': (r['title'] as String?) ?? '',
        'description': (r['description'] as String?) ?? '',
        'startDate': (r['start_date'] as String?) ?? '',
        'endDate': (r['end_date'] as String?) ?? '',
        'startTime': (r['start_time'] as String?) ?? '',
        'endTime': (r['end_time'] as String?) ?? '',
        'allDay': allDay,
        'color': (r['color'] as String?) ?? 'blue',
        'location': (r['location'] as String?) ?? '',
        'category': (r['category'] as String?) ?? 'My calendar',
        'recurrence': (r['recurrence'] as String?) ?? 'none',
        'reminderMin': (r['reminder_min'] as int?) ?? -1,
      };
    }).where((e) => (e['clientKey'] as String).isNotEmpty).toList();
  }

  /// Mark pushed rows clean; drop tombstones that the server has now removed.
  Future<void> markEventsPushed(List<Map<String, dynamic>> mapping) async {
    final d = await db;
    await _ensureCalendarTable(d);
    for (final m in mapping) {
      final ck = m['clientKey'] as String?;
      if (ck == null) continue;
      final rows = await d.query('calendar_events',
          where: 'client_key = ?', whereArgs: [ck], limit: 1);
      if (rows.isEmpty) continue;
      if (((rows.first['deleted'] as int?) ?? 0) == 1) {
        await d.delete('calendar_events', where: 'client_key = ?', whereArgs: [ck]);
      } else {
        await d.update('calendar_events',
            {'dirty': 0, 'cloud_id': m['cloudId']},
            where: 'client_key = ?', whereArgs: [ck]);
      }
    }
  }

  /// Merge events pulled from the cloud. Local rows with pending changes
  /// (dirty=1) are left untouched so unsynced edits are not clobbered.
  Future<void> applyRemoteEvents(List<Map<String, dynamic>> remote) async {
    final d = await db;
    await _ensureCalendarTable(d);
    for (final r in remote) {
      final ck = r['clientKey'] as String?;
      if (ck == null || ck.isEmpty) continue;
      final allDay = r['allDay'] == true;
      final values = <String, Object?>{
        'title': r['title'] ?? '',
        'description': r['description'] ?? '',
        'start_date': r['startDate'] ?? '',
        'end_date': (r['endDate'] ?? r['startDate']) ?? '',
        'start_time': allDay ? '' : (r['startTime'] ?? ''),
        'end_time': allDay ? '' : (r['endTime'] ?? ''),
        'all_day': allDay ? 1 : 0,
        'color': r['color'] ?? 'blue',
        'location': r['location'] ?? '',
        'category': r['category'] ?? 'My calendar',
        'recurrence': r['recurrence'] ?? 'none',
        'reminder_min': (r['reminderMin'] is int) ? r['reminderMin'] : -1,
        'cloud_id': r['cloudId'],
        'dirty': 0,
        'deleted': 0,
      };
      final existing = await d.query('calendar_events',
          where: 'client_key = ?', whereArgs: [ck], limit: 1);
      if (existing.isEmpty) {
        values['client_key'] = ck;
        values['created_at'] = DateTime.now().toIso8601String();
        await d.insert('calendar_events', values);
      } else if (((existing.first['dirty'] as int?) ?? 0) == 0) {
        await d.update('calendar_events', values,
            where: 'client_key = ?', whereArgs: [ck]);
      }
    }
  }

  /// Upcoming reminder occurrences (next [days] days) for events that have a
  /// reminder set — used by Reminders to (re)schedule OS notifications.
  /// Each entry: nid (stable 31-bit notification id), title, body,
  /// fireAt (DateTime = event start − reminder_min; all-day events count as
  /// starting at 09:00).
  Future<List<Map<String, dynamic>>> getUpcomingReminders(
      {int days = 62, int max = 64}) async {
    final d = await db;
    await _ensureCalendarTable(d);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(Duration(days: days));
    List<Map<String, Object?>> rows;
    try {
      rows = await d.query('calendar_events',
          where: '(deleted IS NULL OR deleted = 0) AND reminder_min >= 0');
    } catch (_) {
      return const [];
    }
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final remind = (r['reminder_min'] as int?) ?? -1;
      if (remind < 0) continue;
      final base = _calParseDate(r['start_date']);
      final rec = (r['recurrence'] as String?) ?? 'none';
      final occs = (rec == 'none' || rec.isEmpty)
          ? [base]
          : _expandOccurrences(base, rec, from, to);
      final allDay = ((r['all_day'] as int?) ?? 1) == 1;
      final st = (r['start_time'] as String?) ?? '';
      final loc = (r['location'] as String?) ?? '';
      for (final occ in occs) {
        if (occ.isBefore(from) || occ.isAfter(to)) continue;
        // Anchor: timed events use start_time; all-day events use the user's
        // "Remind at" clock (also in start_time, default 09:00). Pure + tested.
        final fireAt = rl.reminderFireTime(
            occ: occ, startTime: st, reminderMin: remind, now: now);
        if (fireAt == null) continue;
        out.add({
          'nid': '${r['id']}-${_calDateKey(occ)}'.hashCode & 0x7fffffff,
          'title': ((r['title'] as String?)?.isNotEmpty ?? false)
              ? r['title'] as String
              : 'Event',
          'body': [
            allDay ? 'All day' : 'Starts at $st',
            if (loc.isNotEmpty) loc,
          ].join(' · '),
          'fireAt': fireAt,
        });
      }
    }
    out.sort((a, b) =>
        (a['fireAt'] as DateTime).compareTo(b['fireAt'] as DateTime));
    return out.take(max).toList();
  }

  /// Wipe all locally-cached calendar data (events, tasks, custom calendars).
  /// Called on explicit logout and on account switch so one user's data can
  /// never leak into — or be re-synced under — the next account signed in on
  /// the same device (qa-audit DATA-1). Default calendars re-seed automatically
  /// via _ensureLists on next access.
  Future<void> clearLocalData() async {
    final d = await db;
    for (final t in const ['calendar_events', 'calendar_tasks', 'calendar_lists']) {
      try {
        await d.delete(t);
      } catch (_) {/* table may not exist yet — nothing to clear */}
    }
  }

  // ─── Tasks (Google-Tasks-style to-dos) ────────────────────────────────────
  Future<void> _ensureTasks(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS calendar_tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        notes TEXT DEFAULT '',
        due_date TEXT DEFAULT '',
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getCalendarTasks() async {
    final d = await db;
    await _ensureTasks(d);
    final rows = await d.query('calendar_tasks',
        orderBy: "completed ASC, (due_date = '') ASC, due_date ASC, id DESC");
    return rows
        .map((r) => <String, dynamic>{
              'id': r['id'] as int?,
              'title': (r['title'] as String?) ?? '',
              'notes': (r['notes'] as String?) ?? '',
              'dueDate': (r['due_date'] as String?) ?? '',
              'completed': ((r['completed'] as int?) ?? 0) == 1,
            })
        .toList();
  }

  Future<int> saveCalendarTask({
    int? id,
    required String title,
    String notes = '',
    String dueDate = '',
  }) async {
    final d = await db;
    await _ensureTasks(d);
    final values = <String, Object?>{
      'title': title,
      'notes': notes,
      'due_date': dueDate,
    };
    if (id == null) {
      values['created_at'] = DateTime.now().toIso8601String();
      return d.insert('calendar_tasks', values);
    }
    await d.update('calendar_tasks', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> toggleCalendarTask(int id, bool done) async {
    final d = await db;
    await _ensureTasks(d);
    await d.update('calendar_tasks', {'completed': done ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCalendarTask(int id) async {
    final d = await db;
    await _ensureTasks(d);
    await d.delete('calendar_tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Search personal events by title/description/location (newest first).
  Future<List<Map<String, dynamic>>> searchCalendarEvents(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final d = await db;
    await _ensureCalendarTable(d);
    final like = '%$q%';
    final rows = await d.rawQuery(
      'SELECT * FROM calendar_events '
      'WHERE (deleted IS NULL OR deleted = 0) '
      'AND (title LIKE ? OR description LIKE ? OR location LIKE ?) '
      'ORDER BY start_date DESC LIMIT 100',
      [like, like, like],
    );
    return rows.map((r) {
      final allDay = ((r['all_day'] as int?) ?? 1) == 1;
      return <String, dynamic>{
        'key': 'cev-${r['id']}',
        'refId': r['id'] as int?,
        'source': 'event',
        'title': (r['title'] as String?) ?? '',
        'date': _calParseDate(r['start_date']),
        'startDate': _calParseDate(r['start_date']),
        'endDate': _calParseDate(((r['end_date'] as String?)?.isNotEmpty ?? false)
            ? r['end_date']
            : r['start_date']),
        'allDay': allDay,
        'time': allDay ? null : (r['start_time'] as String?),
        'endTime': allDay ? null : (r['end_time'] as String?),
        'color': (r['color'] as String?) ?? 'blue',
        'location': (r['location'] as String?) ?? '',
        'description': (r['description'] as String?) ?? '',
        'category': (r['category'] as String?) ?? 'My calendar',
        'recurrence': (r['recurrence'] as String?) ?? 'none',
        'editable': true,
      };
    }).toList();
  }

  /// Aggregate every dated thing in [from]‥[to] (inclusive) into a single,
  /// normalised event list the calendar screen can render directly. Each entry:
  ///   key, source, title, date(DateTime), allDay, time, endTime, amount,
  ///   status, color, editable, refId, description, location, startDate, endDate
  Future<List<Map<String, dynamic>>> aggregateEvents({
    required DateTime from,
    required DateTime to,
    bool eventsOnly = false, // standalone Calendar app: personal events only
  }) async {
    final d = await db;
    await _ensureCalendarTable(d);
    final fromKey = _calDateKey(from);
    final toKey = _calDateKey(to);
    final out = <Map<String, dynamic>>[];

    Future<List<Map<String, Object?>>> q(String table, String col, String where,
        List<Object?> args) async {
      try {
        return await d.rawQuery(
          'SELECT * FROM $table WHERE substr($col,1,10) BETWEEN ? AND ? $where',
          [fromKey, toKey, ...args],
        );
      } catch (_) {
        return const [];
      }
    }

    // Hidden categories (calendars toggled off in the drawer).
    final hidden = <String>{};
    try {
      for (final r in await d
          .query('calendar_lists', where: 'visible = 0', columns: ['name'])) {
        hidden.add((r['name'] as String?) ?? '');
      }
    } catch (_) {/* lists table missing */}

    // 1) Standalone user events (editable) — with recurrence expansion.
    // Recurring events are queried over ALL rows (not date-bounded) so a series
    // that started before the window still produces occurrences inside it.
    List<Map<String, Object?>> evRows;
    try {
      evRows = await d.query('calendar_events',
          where: 'deleted IS NULL OR deleted = 0');
    } catch (_) {
      evRows = const [];
    }
    for (final r in evRows) {
      final category = (r['category'] as String?) ?? 'My calendar';
      if (hidden.contains(category)) continue;
      final allDay = ((r['all_day'] as int?) ?? 1) == 1;
      final recurrence = (r['recurrence'] as String?) ?? 'none';
      final base = _calParseDate(r['start_date']);

      Map<String, dynamic> mk(DateTime date, DateTime endDate, String key) => {
            'key': key,
            'refId': r['id'] as int?,
            'source': 'event',
            'title': (r['title'] as String?) ?? '',
            'date': date,
            'startDate': date,
            'endDate': endDate,
            'allDay': allDay,
            'time': allDay ? null : (r['start_time'] as String?),
            'endTime': allDay ? null : (r['end_time'] as String?),
            'amount': null,
            'status': null,
            'color': (r['color'] as String?) ?? 'blue',
            'location': (r['location'] as String?) ?? '',
            'description': (r['description'] as String?) ?? '',
            'category': category,
            'recurrence': recurrence,
            'reminderMin': (r['reminder_min'] as int?) ?? -1,
            'editable': true,
          };

      if (recurrence == 'none' || recurrence.isEmpty) {
        final end = _calParseDate(
            ((r['end_date'] as String?)?.isNotEmpty ?? false)
                ? r['end_date']
                : r['start_date']);
        // Keep if the [base..end] span intersects the window.
        if (!base.isAfter(to) && !end.isBefore(from)) {
          out.add(mk(base, end, 'cev-${r['id']}'));
        }
      } else {
        for (final occ in _expandOccurrences(base, recurrence, from, to)) {
          out.add(mk(occ, occ, 'cev-${r['id']}-${_calDateKey(occ)}'));
        }
      }
    }

    // Standalone "Kuk Calendar" app → personal events only, no business data.
    if (eventsOnly) return out;

    // 2) Invoices due (sale, not fully paid) — read-only
    for (final r in await q('invoices', 'date',
        "AND type = 'sale' AND status != 'paid'", const [])) {
      out.add({
        'key': 'inv-${r['id']}',
        'refId': r['id'] as int?,
        'source': 'invoice',
        'title':
            '${(r['party_name'] as String?)?.isNotEmpty == true ? r['party_name'] : 'Invoice'} · ${(r['invoice_no'] as String?) ?? ''}',
        'date': _calParseDate(r['date']),
        'allDay': true,
        'time': null,
        'amount': ((r['due_amount'] as num?) ?? (r['total'] as num?) ?? 0).toDouble(),
        'status': (r['status'] as String?) ?? 'unpaid',
        'color': 'red',
        'editable': false,
      });
    }

    // 3) Payments received — read-only
    for (final r
        in await q('payments', 'date', "AND type = 'in'", const [])) {
      out.add({
        'key': 'pay-${r['id']}',
        'refId': r['id'] as int?,
        'source': 'payment',
        'title':
            'Payment · ${(r['party_name'] as String?)?.isNotEmpty == true ? r['party_name'] : ''}',
        'date': _calParseDate(r['date']),
        'allDay': true,
        'time': null,
        'amount': ((r['amount'] as num?) ?? 0).toDouble(),
        'status': 'received',
        'color': 'green',
        'editable': false,
      });
    }

    // 4) Expenses — read-only
    for (final r in await q('expenses', 'date', '', const [])) {
      out.add({
        'key': 'exp-${r['id']}',
        'refId': r['id'] as int?,
        'source': 'expense',
        'title': 'Expense · ${(r['category'] as String?) ?? 'Other'}',
        'date': _calParseDate(r['date']),
        'allDay': true,
        'time': null,
        'amount': ((r['amount'] as num?) ?? 0).toDouble(),
        'status': null,
        'color': 'purple',
        'editable': false,
      });
    }

    // 5) Cheques — by due date, read-only
    for (final r in await q('cheques', 'due_date',
        "AND status != 'cleared'", const [])) {
      out.add({
        'key': 'chq-${r['id']}',
        'refId': r['id'] as int?,
        'source': 'cheque',
        'title':
            'Cheque · ${(r['party_name'] as String?)?.isNotEmpty == true ? r['party_name'] : ''}',
        'date': _calParseDate(r['due_date']),
        'allDay': true,
        'time': null,
        'amount': ((r['amount'] as num?) ?? 0).toDouble(),
        'status': (r['status'] as String?) ?? 'pending',
        'color': 'orange',
        'editable': false,
      });
    }

    // 6) Service reminders — by service date, read-only
    for (final r in await q('service_reminders', 'service_date',
        "AND status = 'active'", const [])) {
      out.add({
        'key': 'svc-${r['id']}',
        'refId': r['id'] as int?,
        'source': 'reminder',
        'title':
            '${(r['title'] as String?)?.isNotEmpty == true ? r['title'] : 'Service'}${(r['party_name'] as String?)?.isNotEmpty == true ? ' · ${r['party_name']}' : ''}',
        'date': _calParseDate(r['service_date']),
        'allDay': true,
        'time': null,
        'amount': null,
        'status': 'active',
        'color': 'teal',
        'editable': false,
      });
    }

    return out;
  }
}
