import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db.dart';
import '../ics.dart';
import '../db_calendar.dart';
import '../money.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../app_info.dart';
import '../cal_sync.dart';
import '../notifications.dart';
import '../reminder_logic.dart' as rl;
import '../theme/theme_controller.dart';
import 'calendar_tasks_screen.dart';
import 'calendar_login_screen.dart';

/// Kuk Calendar — a Google-Calendar-style personal calendar. Month / Week /
/// 3-day / Day / Schedule views, a navigation drawer, search, and add/edit/
/// delete events. Offline-first. In the standalone build it shows personal
/// events only; in the KukBook build it also overlays business data.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

/// Unused in the standalone app (there is no ERP to open) — kept null so the
/// shared screen code compiles without change.
Widget Function()? kukCalendarFullAppBuilder;

/// This IS the standalone Kuk Calendar app — always a pure personal calendar
/// (no KukBook business data, no ERP link).
const bool kStandaloneCalendar = true;

enum CalView { schedule, day, threeDay, week, month }

extension on CalView {
  String get label => switch (this) {
        CalView.schedule => 'Schedule',
        CalView.day => 'Day',
        CalView.threeDay => '3 days',
        CalView.week => 'Week',
        CalView.month => 'Month',
      };
  IconData get icon => switch (this) {
        CalView.schedule => Icons.view_agenda_outlined,
        CalView.day => Icons.view_day_outlined,
        CalView.threeDay => Icons.view_column_outlined,
        CalView.week => Icons.view_week_outlined,
        CalView.month => Icons.calendar_view_month_outlined,
      };
}

// Event colour palette (name → colour).
const Map<String, Color> _palette = {
  'blue': Color(0xFF3B82F6),
  'green': Color(0xFF16A34A),
  'red': Color(0xFFDC2626),
  'orange': Color(0xFFD97706),
  'purple': Color(0xFF7C3AED),
  'teal': Color(0xFF0D9488),
  'pink': Color(0xFFDB2777),
  'indigo': Color(0xFF4F46E5),
};
Color _colorFor(String? c) => _palette[c] ?? _palette['blue']!;
const List<String> _userColors = [
  'blue', 'green', 'red', 'orange', 'purple', 'teal', 'pink', 'indigo'
];

class _Source {
  final String label;
  final IconData icon;
  final String color;
  const _Source(this.label, this.icon, this.color);
}

const Map<String, _Source> _sources = {
  'event': _Source('My events', Icons.event, 'blue'),
  'invoice': _Source('Invoices due', Icons.receipt_long, 'red'),
  'payment': _Source('Payments', Icons.payments, 'green'),
  'expense': _Source('Expenses', Icons.shopping_bag_outlined, 'purple'),
  'cheque': _Source('Cheques', Icons.account_balance_outlined, 'orange'),
  'reminder': _Source('Reminders', Icons.notifications_active_outlined, 'teal'),
  'task': _Source('KukTask', Icons.check_circle_outline, 'indigo'),
};

final _money = Money.fmt(2);
final _dayHeaderFmt = DateFormat('EEEE, d MMMM');
final _monthFmt = DateFormat('MMMM yyyy');

const double _hourPx = 56;

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _startOfWeek(DateTime d) =>
    _dateOnly(d).subtract(Duration(days: d.weekday % 7)); // Sunday start

int _toMin(String? hm) {
  if (hm == null || !hm.contains(':')) return 0;
  final p = hm.split(':');
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

String _fmtTime(String? hm) {
  if (hm == null || hm.isEmpty || !hm.contains(':')) return '';
  final parts = hm.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final ap = h >= 12 ? 'PM' : 'AM';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${m.toString().padLeft(2, '0')} $ap';
}

class _CalendarScreenState extends State<CalendarScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CalView _view = CalView.month;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];
  // Read-only KukTask due-date overlay (ARCH-1); fetched from the shared backend
  // and merged into _events so it renders like any other calendar item.
  List<Map<String, dynamic>> _taskOverlay = [];
  List<Map<String, dynamic>> _lists = []; // calendars/categories
  final Set<String> _hidden = {}; // hidden source keys (KukBook overlay only)

  bool _syncing = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _focused = _dateOnly(DateTime.now());
    _selected = _focused;
    _load();
    _loadLists();
    _initSync();
    appVersionString().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  Future<void> _initSync() async {
    if (!kStandaloneCalendar) return;
    await CalSync.instance.load();
    if (mounted) setState(() {});
    if (CalSync.instance.isLoggedIn) {
      await _syncNow(silent: true);
      await _loadTasks();
    }
  }

  /// Fetch the read-only KukTask due-date overlay and re-render (ARCH-1). Safe
  /// when signed out / offline — returns nothing and the overlay stays empty.
  Future<void> _loadTasks() async {
    if (!kStandaloneCalendar) return;
    final tasks = await CalSync.instance.myUpcomingTasks();
    final items = <Map<String, dynamic>>[];
    for (final t in tasks) {
      final due = DateTime.tryParse('${t['dueDate'] ?? ''}');
      if (due == null) continue;
      items.add({
        'title': '${t['title'] ?? 'Task'}',
        'date': DateTime(due.year, due.month, due.day),
        'allDay': true,
        'color': 'indigo',
        'source': 'task',
        'editable': false,
        'category': '${t['companyName'] ?? ''}',
        'status': '${t['status'] ?? ''}',
      });
    }
    _taskOverlay = items;
    if (mounted) await _load(); // re-merge overlay + events, then render
  }

  Future<void> _pickTheme() async {
    final m = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in const {
              ThemeMode.system: 'System default',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            }.entries)
              RadioListTile<ThemeMode>(
                value: e.key,
                groupValue: ThemeController.instance.value,
                title: Text(e.value),
                onChanged: (v) => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    );
    if (m != null) {
      await ThemeController.instance.set(m);
      if (mounted) setState(() {});
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Export all local events to a standard .ics file and open the share sheet.
  Future<void> _exportIcs() async {
    try {
      final events = await AppDb.instance.exportableEvents();
      if (events.isEmpty) {
        _toast('No events to export');
        return;
      }
      final ics = generateIcs(events, stamp: DateTime.now());
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/kuk-calendar.ics');
      await f.writeAsString(ics);
      await Share.shareXFiles([XFile(f.path)],
          subject: 'Kuk Calendar export');
    } catch (_) {
      _toast('Export failed');
    }
  }

  /// Pick an .ics file and import its events into the local calendar.
  Future<void> _importIcs() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = res?.files.single.path;
      if (path == null) return;
      final text = await File(path).readAsString();
      final events = parseIcs(text);
      if (events.isEmpty) {
        _toast('No events found in that file');
        return;
      }
      final n = await AppDb.instance.importIcsEvents(events);
      await _load();
      if (CalSync.instance.isLoggedIn) _syncNow(silent: true);
      _toast('Imported $n event${n == 1 ? '' : 's'}');
    } catch (_) {
      _toast('Import failed');
    }
  }

  Future<void> _signIn() async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CalendarLoginScreen()));
    if (mounted) setState(() {});
    if (ok == true) await _syncNow();
  }

  Future<void> _signOut() async {
    await CalSync.instance.logout();
    _taskOverlay = []; // drop the previous user's task overlay
    if (mounted) {
      setState(() {});
      await _load();
    }
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (!CalSync.instance.isLoggedIn) return;
    setState(() => _syncing = true);
    try {
      await CalSync.instance.syncNow();
      await _loadLists();
      await _loadTasks(); // refresh KukTask overlay + re-render (calls _load)
      if (!silent && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Synced')));
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Sync failed: ${e.toString().replaceFirst('Exception: ', '')}')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _loadLists() async {
    try {
      final l = await AppDb.instance.getCalendarLists();
      if (mounted) setState(() => _lists = l);
    } catch (_) {/* ignore */}
  }

  String _listColor(String name) {
    for (final l in _lists) {
      if (l['name'] == name) return (l['color'] as String?) ?? 'blue';
    }
    return 'blue';
  }

  Future<void> _addCalendar() async {
    final ctl = TextEditingController();
    var color = 'green';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New calendar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _userColors.map((c) {
                  final sel = c == color;
                  return GestureDetector(
                    onTap: () => setS(() => color = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _colorFor(c),
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: AppColors.textPrimary, width: 2)
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      await AppDb.instance.addCalendarList(ctl.text.trim(), color);
      await _loadLists();
    }
  }

  DateTime get _gridStart {
    final first = DateTime(_focused.year, _focused.month, 1);
    return first.subtract(Duration(days: first.weekday % 7));
  }

  // The date window to load for the current view (generous so nav feels instant).
  (DateTime, DateTime) _range() {
    switch (_view) {
      case CalView.month:
        final s = _gridStart;
        return (s, s.add(const Duration(days: 41)));
      case CalView.week:
        final s = _startOfWeek(_focused);
        return (s, s.add(const Duration(days: 6)));
      case CalView.threeDay:
        return (_focused, _focused.add(const Duration(days: 2)));
      case CalView.day:
        return (_focused, _focused);
      case CalView.schedule:
        return (_focused, _focused.add(const Duration(days: 60)));
    }
  }

  Future<void> _load() async {
    // Don't blank the screen on every navigation — the local DB is instant, so
    // flashing a full-screen spinner on each month/day step looks janky. Only
    // the very first load shows LoadingView (via the initial _loading=true).
    try {
      final (start, end) = _range();
      final list = await AppDb.instance
          .aggregateEvents(from: start, to: end, eventsOnly: kStandaloneCalendar);
      if (mounted) {
        setState(() {
          _events = [...list, ..._taskOverlay];
          _loading = false;
        });
      }
      // Keep OS reminder notifications in sync with the (possibly changed)
      // event set — no-op when nothing changed, so safe on every navigation.
      Reminders.rescheduleAll();
    } catch (_) {
      if (mounted) setState(() { _events = []; _loading = false; });
    }
  }

  Map<String, List<Map<String, dynamic>>> get _byDay {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in _events) {
      if (_hidden.contains(e['source'])) continue;
      final start = e['date'] as DateTime;
      final end = (e['endDate'] as DateTime?) ?? start;
      var d = _dateOnly(start);
      final last = _dateOnly(end);
      var guard = 0;
      while (!d.isAfter(last) && guard < 60) {
        map.putIfAbsent(_key(d), () => []).add(e);
        d = d.add(const Duration(days: 1));
        guard++;
      }
    }
    for (final v in map.values) {
      v.sort((a, b) {
        final aa = a['allDay'] == true, ba = b['allDay'] == true;
        if (aa != ba) return aa ? -1 : 1;
        return ((a['time'] as String?) ?? '')
            .compareTo((b['time'] as String?) ?? '');
      });
    }
    return map;
  }

  void _step(int dir) {
    setState(() {
      switch (_view) {
        case CalView.month:
          _focused = DateTime(_focused.year, _focused.month + dir, 1);
        case CalView.week:
          _focused = _focused.add(Duration(days: 7 * dir));
        case CalView.threeDay:
          _focused = _focused.add(Duration(days: 3 * dir));
        case CalView.day:
          _focused = _focused.add(Duration(days: dir));
        case CalView.schedule:
          _focused = _focused.add(Duration(days: 30 * dir));
      }
    });
    _load();
  }

  void _goToday() {
    setState(() {
      _focused = _dateOnly(DateTime.now());
      _selected = _focused;
    });
    _load();
  }

  void _setView(CalView v) {
    setState(() => _view = v);
    _load();
  }

  // Tapping the "Month YYYY ▾" title opens Today + view switching, replacing the
  // old app-bar Today button and overflow menu so the bar matches the design.
  Future<void> _openViewMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.today_outlined, color: AppColors.primary),
              title: const Text('Today'),
              onTap: () {
                Navigator.pop(ctx);
                _goToday();
              },
            ),
            const Divider(height: 1),
            for (final v in CalView.values)
              ListTile(
                leading: Icon(v.icon,
                    color: v == _view ? AppColors.primary : AppColors.textSecondary),
                title: Text(v.label),
                trailing: v == _view
                    ? Icon(Icons.check, color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setView(v);
                },
              ),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (_view) {
      case CalView.month:
        return _monthFmt.format(_focused);
      case CalView.day:
        return DateFormat('EEE, d MMM').format(_focused);
      case CalView.schedule:
        return 'Schedule';
      case CalView.week:
      case CalView.threeDay:
        final n = _view == CalView.week ? 7 : 3;
        final s = _view == CalView.week ? _startOfWeek(_focused) : _focused;
        final e = s.add(Duration(days: n - 1));
        final sameMonth = s.month == e.month && s.year == e.year;
        return sameMonth
            ? '${s.day} – ${DateFormat('d MMM').format(e)}'
            : '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM').format(e)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: _buildDrawer(),
      appBar: AppBar(
        titleSpacing: 4,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _openViewMenu,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(_title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
                context: context, delegate: _EventSearchDelegate(_openExisting)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 14),
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary,
                child: Text(
                  _accountInitial(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEventForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading ? const LoadingView() : _buildBody(),
    );
  }

  String _accountInitial() {
    final n = CalSync.instance.userName?.trim() ?? '';
    return n.isNotEmpty ? n.substring(0, 1).toUpperCase() : 'K';
  }

  Widget _buildBody() {
    switch (_view) {
      case CalView.month:
        return _monthBody();
      case CalView.schedule:
        return _scheduleBody();
      case CalView.day:
        return _TimeGrid(
            days: [_focused], byDay: _byDay, onEvent: _openExisting, onSlot: _newAt);
      case CalView.threeDay:
        return _TimeGrid(
            days: List.generate(3, (i) => _focused.add(Duration(days: i))),
            byDay: _byDay,
            onEvent: _openExisting,
            onSlot: _newAt);
      case CalView.week:
        final s = _startOfWeek(_focused);
        return _TimeGrid(
            days: List.generate(7, (i) => s.add(Duration(days: i))),
            byDay: _byDay,
            onEvent: _openExisting,
            onSlot: _newAt);
    }
  }

  // ─── Drawer ───────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                Icon(Icons.calendar_month, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Kuk Calendar',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Divider(height: 1),
            if (kStandaloneCalendar) ...[
              if (CalSync.instance.isLoggedIn) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      ((CalSync.instance.userName ?? '?').isNotEmpty
                              ? CalSync.instance.userName!
                              : '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(CalSync.instance.userName?.isNotEmpty == true
                      ? CalSync.instance.userName!
                      : 'My account'),
                  subtitle: Text(_syncing ? 'Syncing…' : 'Tap to sync now'),
                  trailing: _syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  onTap: _syncing
                      ? null
                      : () {
                          Navigator.pop(context);
                          _syncNow();
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () {
                    Navigator.pop(context);
                    _signOut();
                  },
                ),
              ] else
                ListTile(
                  leading: Icon(Icons.cloud_sync_outlined,
                      color: AppColors.primary),
                  title: const Text('Sign in or create account'),
                  subtitle: const Text('Back up & sync your calendar'),
                  onTap: () {
                    Navigator.pop(context);
                    _signIn();
                  },
                ),
              const Divider(height: 1),
            ],
            for (final v in CalView.values)
              ListTile(
                leading: Icon(v.icon,
                    color: v == _view ? AppColors.primary : null),
                title: Text(v.label,
                    style: TextStyle(
                        color: v == _view ? AppColors.primary : null,
                        fontWeight:
                            v == _view ? FontWeight.w700 : FontWeight.w500)),
                selected: v == _view,
                onTap: () {
                  Navigator.pop(context);
                  _setView(v);
                },
              ),
            if (kStandaloneCalendar && _lists.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('My calendars',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              for (final l in _lists)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: l['visible'] == true,
                  activeColor: _colorFor(l['color'] as String?),
                  title: Row(children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                          color: _colorFor(l['color'] as String?),
                          shape: BoxShape.circle),
                    ),
                    Text(l['name'] as String? ?? ''),
                  ]),
                  onChanged: (v) async {
                    await AppDb.instance
                        .setListVisible(l['name'] as String, v ?? true);
                    await _loadLists();
                    await _load();
                  },
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add, size: 20),
                title: const Text('Add calendar'),
                onTap: () {
                  Navigator.pop(context);
                  _addCalendar();
                },
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search'),
              onTap: () {
                Navigator.pop(context);
                showSearch(
                    context: context,
                    delegate: _EventSearchDelegate(_openExisting));
              },
            ),
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: const Text('Go to today'),
              onTap: () {
                Navigator.pop(context);
                _goToday();
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Export to .ics'),
              onTap: () {
                Navigator.pop(context);
                _exportIcs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Import .ics file'),
              onTap: () {
                Navigator.pop(context);
                _importIcs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Theme'),
              subtitle: Text(ThemeController.instance.label),
              onTap: () {
                Navigator.pop(context);
                _pickTheme();
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rtl_outlined),
              title: const Text('Tasks'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CalendarTasksScreen()));
              },
            ),
            if (kukCalendarFullAppBuilder != null)
              ListTile(
                leading: const Icon(Icons.apps),
                title: const Text('Open KukBook'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => kukCalendarFullAppBuilder!()));
                },
              ),
            if (kStandaloneCalendar && _version.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Text('Kuk Calendar $_version',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Month view ───────────────────────────────────────────────────────────
  Widget _monthBody() {
    final byDay = _byDay;
    final selectedEvents = byDay[_key(_selected)] ?? const [];
    return Column(
      children: [
        _weekdayRow(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -120) {
              _step(1);
            } else if (v > 120) {
              _step(-1);
            }
          },
          child: _monthGrid(byDay),
        ),
        if (!kStandaloneCalendar) _filterChips(),
        const SizedBox(height: 4),
        Expanded(child: _dayAgenda(selectedEvents)),
      ],
    );
  }

  Widget _weekdayRow() {
    const labels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: labels
            .map((l) => Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(l,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: AppColors.textMuted)),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _monthGrid(Map<String, List<Map<String, dynamic>>> byDay) {
    final start = _gridStart;
    final todayKey = _key(DateTime.now());
    final weeks = <Widget>[];
    for (var w = 0; w < 6; w++) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        final day = start.add(Duration(days: w * 7 + i));
        final inMonth = day.month == _focused.month;
        final isToday = _key(day) == todayKey;
        final isSelected = _key(day) == _key(_selected);
        final dayEvents = byDay[_key(day)] ?? const [];
        cells.add(Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selected = day),
            onDoubleTap: () {
              setState(() {
                _selected = day;
                _focused = day;
              });
              _setView(CalView.day);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 56,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? Colors.white
                              : inMonth
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary.withOpacity(0.5),
                        )),
                  ),
                  const SizedBox(height: 3),
                  _eventBars(dayEvents),
                ],
              ),
            ),
          ),
        ));
      }
      weeks.add(Row(children: cells));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(children: weeks),
    );
  }

  Widget _eventBars(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return const SizedBox(height: 6);
    final show = events.take(3).toList();
    return SizedBox(
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in show)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: _colorFor(e['color'] as String?),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: _sources.entries.map((e) {
          final off = _hidden.contains(e.key);
          final c = _colorFor(e.value.color);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              selected: !off,
              showCheckmark: false,
              avatar: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: off ? Colors.grey : c, shape: BoxShape.circle),
              ),
              label: Text(e.value.label, style: const TextStyle(fontSize: 12)),
              onSelected: (_) => setState(() {
                off ? _hidden.remove(e.key) : _hidden.add(e.key);
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dayAgenda(List<Map<String, dynamic>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(_dayHeaderFmt.format(_selected),
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        Expanded(
          child: events.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nothing scheduled',
                  subtitle: 'Tap + to add an event for this day.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _eventTile(events[i]),
                ),
        ),
      ],
    );
  }

  // ─── Schedule (agenda) view ───────────────────────────────────────────────
  Widget _scheduleBody() {
    final byDay = _byDay;
    final keys = byDay.keys.toList()..sort();
    if (keys.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nothing scheduled',
        subtitle: 'Tap + to add an event.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      children: [
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
              _dayHeaderFmt.format(DateTime.parse(k)),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
          for (final e in byDay[k]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _eventTile(e),
            ),
        ]
      ],
    );
  }

  Widget _eventTile(Map<String, dynamic> e) {
    final color = _colorFor(e['color'] as String?);
    final source = _sources[e['source']] ?? _sources['event']!;
    final amount = e['amount'] as double?;
    final time = e['time'] as String?;
    final bits = <String>[];
    if (e['allDay'] != true && (time?.isNotEmpty ?? false)) {
      final end = e['endTime'] as String?;
      bits.add(_fmtTime(time) +
          ((end?.isNotEmpty ?? false) ? ' – ${_fmtTime(end)}' : ''));
    } else if (e['allDay'] == true) {
      bits.add('All day');
    }
    if (amount != null) bits.add(_money.format(amount));
    final status = e['status'] as String?;
    if (status != null && status.isNotEmpty) bits.add(status);

    final category = (e['category'] as String?) ?? source.label;
    return AppCard(
      onTap: () => _openExisting(e),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(source.icon, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((e['title'] as String?) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                if (bits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(bits.join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (category.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Open a tapped event: editable → editor; read-only business → detail dialog.
  void _openExisting(Map<String, dynamic> e) {
    if (e['editable'] == true) {
      _openEventForm(existing: e);
    } else {
      _showDetail(e);
    }
  }

  void _newAt(DateTime day, int hour) {
    _openEventForm(initialDate: day, initialHour: hour);
  }

  void _showDetail(Map<String, dynamic> e) {
    final source = _sources[e['source']] ?? _sources['event']!;
    final color = _colorFor(e['color'] as String?);
    final amount = e['amount'] as double?;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(source.icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text((e['title'] as String?) ?? '')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.label_outline, source.label),
            _detailRow(Icons.calendar_today_outlined,
                _dayHeaderFmt.format(e['date'] as DateTime)),
            if (amount != null)
              _detailRow(Icons.payments_outlined, _money.format(amount)),
            if ((e['status'] as String?)?.isNotEmpty ?? false)
              _detailRow(Icons.info_outline, 'Status: ${e['status']}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );

  // ─── Add / edit a personal event ──────────────────────────────────────────
  Future<void> _openEventForm({
    Map<String, dynamic>? existing,
    DateTime? initialDate,
    int? initialHour,
  }) async {
    final isEdit = existing != null;
    final titleCtl =
        TextEditingController(text: (existing?['title'] as String?) ?? '');
    final descCtl = TextEditingController(
        text: (existing?['description'] as String?) ?? '');
    final locCtl =
        TextEditingController(text: (existing?['location'] as String?) ?? '');
    var startDate = (existing?['startDate'] as DateTime?) ??
        (existing?['date'] as DateTime?) ??
        initialDate ??
        _selected;
    var endDate = (existing?['endDate'] as DateTime?) ?? startDate;
    var allDay =
        isEdit ? (existing['allDay'] == true) : (initialHour == null);
    var startTime = (existing?['time'] as String?) ??
        (initialHour != null
            ? '${initialHour.toString().padLeft(2, '0')}:00'
            : '09:00');
    var endTime = (existing?['endTime'] as String?) ??
        (initialHour != null
            ? '${((initialHour + 1) % 24).toString().padLeft(2, '0')}:00'
            : '10:00');
    var color = (existing?['color'] as String?) ?? 'blue';
    final catNames = _lists.isNotEmpty
        ? _lists.map((l) => l['name'] as String).toList()
        : <String>['My calendar'];
    var category = (existing?['category'] as String?) ??
        (initialDate == null ? catNames.first : catNames.first);
    if (!catNames.contains(category)) catNames.insert(0, category);
    final rec0 = rl.parseRecurrence((existing?['recurrence'] as String?) ?? 'none');
    var recType = rec0.repeats ? rec0.type : 'none';
    var recInterval = rec0.interval;
    DateTime? recUntil = rec0.until;
    const recLabels = {
      'none': 'Does not repeat',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'yearly': 'Yearly',
    };
    const recUnit = {
      'daily': 'day',
      'weekly': 'week',
      'monthly': 'month',
      'yearly': 'year',
    };
    final reminders = rl.parseReminderOffsets(
        existing?['reminders'] as String?,
        primary: (existing?['reminderMin'] as int?) ?? -1);
    const remLabels = {
      0: 'At time of event',
      10: '10 minutes before',
      30: '30 minutes before',
      60: '1 hour before',
      120: '2 hours before',
      1440: '1 day before',
    };

    final dfmt = DateFormat('dd MMM yyyy');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pickDate(bool isStart) async {
              final d = await showDatePicker(
                context: ctx,
                initialDate: isStart ? startDate : endDate,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                setSheet(() {
                  if (isStart) {
                    startDate = d;
                    if (endDate.isBefore(startDate)) endDate = startDate;
                  } else {
                    endDate = d.isBefore(startDate) ? startDate : d;
                  }
                });
              }
            }

            Future<void> pickTime(bool isStart) async {
              final parts = (isStart ? startTime : endTime).split(':');
              final t = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay(
                  hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
                  minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                ),
              );
              if (t != null) {
                final v =
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                setSheet(() => isStart ? startTime = v : endTime = v);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Text(isEdit ? 'Edit event' : 'New event',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtl,
                      autofocus: !isEdit,
                      decoration: const InputDecoration(
                          labelText: 'Title', hintText: 'Add title'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('All day'),
                      value: allDay,
                      onChanged: (v) => setSheet(() => allDay = v),
                    ),
                    Row(children: [
                      Expanded(
                        child: _pickerField('Start date',
                            dfmt.format(startDate), () => pickDate(true)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pickerField('End date', dfmt.format(endDate),
                            () => pickDate(false)),
                      ),
                    ]),
                    if (!allDay) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _pickerField('Start time',
                              _fmtTime(startTime), () => pickTime(true)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _pickerField('End time', _fmtTime(endTime),
                              () => pickTime(false)),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    Text('Colour',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      children: _userColors.map((c) {
                        final sel = c == color;
                        return GestureDetector(
                          onTap: () => setSheet(() => color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _colorFor(c),
                              shape: BoxShape.circle,
                              border: sel
                                  ? Border.all(
                                      color: AppColors.textPrimary, width: 2)
                                  : null,
                            ),
                            child: sel
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    if (kStandaloneCalendar) ...[
                      DropdownButtonFormField<String>(
                        value:
                            catNames.contains(category) ? category : catNames.first,
                        decoration: const InputDecoration(
                            labelText: 'Calendar',
                            prefixIcon: Icon(Icons.event_note_outlined)),
                        items: catNames
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Row(children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                          color: _colorFor(_listColor(n)),
                                          shape: BoxShape.circle),
                                    ),
                                    Text(n),
                                  ]),
                                ))
                            .toList(),
                        onChanged: (v) => setSheet(() {
                          category = v ?? category;
                          color = _listColor(category);
                        }),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: recType,
                        decoration: const InputDecoration(
                            labelText: 'Repeat',
                            prefixIcon: Icon(Icons.repeat)),
                        items: recLabels.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setSheet(() => recType = v ?? 'none'),
                      ),
                      if (recType != 'none') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('Every ', style: TextStyle(fontSize: 14)),
                            SizedBox(
                              width: 70,
                              child: DropdownButtonFormField<int>(
                                value: recInterval > 12 ? 12 : recInterval,
                                isDense: true,
                                items: [
                                  for (var i = 1; i <= 12; i++)
                                    DropdownMenuItem(value: i, child: Text('$i')),
                                ],
                                onChanged: (v) =>
                                    setSheet(() => recInterval = v ?? 1),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${recUnit[recType]}${recInterval > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _pickerField(
                                'Repeat until',
                                recUntil == null
                                    ? 'Forever'
                                    : dfmt.format(recUntil!),
                                () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: recUntil ?? endDate,
                                    firstDate: startDate,
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setSheet(() => recUntil = picked);
                                  }
                                },
                              ),
                            ),
                            if (recUntil != null)
                              IconButton(
                                tooltip: 'Clear end date',
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () => setSheet(() => recUntil = null),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.notifications_outlined,
                              size: 20, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Text('Reminders',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final m in reminders)
                            InputChip(
                              label: Text(remLabels[m] ?? '$m min before'),
                              onDeleted: () =>
                                  setSheet(() => reminders.remove(m)),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                            onPressed: () async {
                              final choice = await showModalBottomSheet<int>(
                                context: ctx,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final e in remLabels.entries)
                                        if (!reminders.contains(e.key))
                                          ListTile(
                                            title: Text(e.value),
                                            onTap: () =>
                                                Navigator.pop(ctx, e.key),
                                          ),
                                    ],
                                  ),
                                ),
                              );
                              if (choice != null &&
                                  !reminders.contains(choice)) {
                                setSheet(() {
                                  reminders.add(choice);
                                  reminders.sort();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      // All-day events have no start time, so let the user choose
                      // the clock time the reminders fire (default 09:00). Without
                      // this the alarm silently anchored to a fixed 09:00.
                      if (allDay && reminders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _pickerField('Remind at', _fmtTime(startTime),
                            () => pickTime(true)),
                      ],
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: locCtl,
                      decoration: const InputDecoration(
                          labelText: 'Location (optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      if (isEdit)
                        TextButton.icon(
                          onPressed: () async {
                            await AppDb.instance
                                .deleteCalendarEvent(existing['refId'] as int);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          icon: Icon(Icons.delete_outline,
                              color: AppColors.danger),
                          label: Text('Delete',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      const Spacer(),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (titleCtl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Title is required')),
                            );
                            return;
                          }
                          await AppDb.instance.saveCalendarEvent(
                            id: isEdit ? existing['refId'] as int? : null,
                            title: titleCtl.text.trim(),
                            description: descCtl.text.trim(),
                            startDate: startDate,
                            endDate: endDate,
                            startTime: startTime,
                            endTime: endTime,
                            allDay: allDay,
                            color: color,
                            location: locCtl.text.trim(),
                            category: category,
                            recurrence:
                                rl.buildRecurrence(recType, recInterval, recUntil),
                            reminders: reminders,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        child: const Text('Save'),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() => _selected = startDate);
      await _load();
    }
  }

  Widget _pickerField(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}

// ─── Day / Week / 3-day time-grid (hour timeline with event blocks) ──────────
class _TimeGrid extends StatefulWidget {
  final List<DateTime> days;
  final Map<String, List<Map<String, dynamic>>> byDay;
  final void Function(Map<String, dynamic>) onEvent;
  final void Function(DateTime day, int hour) onSlot;
  const _TimeGrid(
      {required this.days,
      required this.byDay,
      required this.onEvent,
      required this.onSlot});

  @override
  State<_TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<_TimeGrid> {
  // Open the timeline scrolled to ~7am so the morning is visible immediately
  // (Google Calendar does the same), instead of starting at midnight.
  final ScrollController _scroll =
      ScrollController(initialScrollOffset: _hourPx * 7);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final byDay = widget.byDay;
    final onEvent = widget.onEvent;
    final onSlot = widget.onSlot;
    final todayKey = _key(DateTime.now());
    return Column(
      children: [
        // Day headers
        Row(children: [
          const SizedBox(width: 52),
          for (final d in days)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(color: AppColors.border, width: .5))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(DateFormat('EEE').format(d),
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _key(d) == todayKey
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle),
                    child: Text('${d.day}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _key(d) == todayKey
                                ? Colors.white
                                : AppColors.textPrimary)),
                  ),
                ]),
              ),
            ),
        ]),
        // All-day row
        _AllDayRow(days: days, byDay: byDay, onEvent: onEvent),
        const Divider(height: 1),
        // Hour grid
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: _hourPx * 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hour labels
                  SizedBox(
                    width: 52,
                    child: Stack(children: [
                      for (var h = 1; h < 24; h++)
                        Positioned(
                          top: h * _hourPx - 7,
                          right: 6,
                          child: Text(_fmtTime('${h.toString().padLeft(2, '0')}:00')
                              .replaceAll(':00', ''),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary)),
                        ),
                    ]),
                  ),
                  for (final d in days)
                    Expanded(child: _DayColumn(day: d, events: byDay[_key(d)] ?? const [], onEvent: onEvent, onSlot: onSlot)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AllDayRow extends StatelessWidget {
  final List<DateTime> days;
  final Map<String, List<Map<String, dynamic>>> byDay;
  final void Function(Map<String, dynamic>) onEvent;
  const _AllDayRow(
      {required this.days, required this.byDay, required this.onEvent});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: EdgeInsets.only(top: 4, right: 6),
            child: Text('all-day',
                textAlign: TextAlign.right,
                style:
                    TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          ),
        ),
        for (final d in days)
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 22),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(color: AppColors.border, width: .5))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e
                      in (byDay[_key(d)] ?? const []).where((e) => e['allDay'] == true))
                    GestureDetector(
                      onTap: () => onEvent(e),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _colorFor(e['color'] as String?),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text((e['title'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> events;
  final void Function(Map<String, dynamic>) onEvent;
  final void Function(DateTime day, int hour) onSlot;
  const _DayColumn(
      {required this.day,
      required this.events,
      required this.onEvent,
      required this.onSlot});

  @override
  Widget build(BuildContext context) {
    final timed = events
        .where((e) => e['allDay'] != true && (e['time'] as String?) != null)
        .toList();
    final laid = _layoutColumns(timed);
    return Container(
      decoration: BoxDecoration(
          border:
              Border(left: BorderSide(color: AppColors.border, width: .5))),
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          children: [
            // hour lines + tap targets
            for (var h = 0; h < 24; h++)
              Positioned(
                top: h * _hourPx,
                left: 0,
                right: 0,
                height: _hourPx,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSlot(day, h),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: AppColors.border, width: .4))),
                  ),
                ),
              ),
            // event blocks
            for (final p in laid)
              Builder(builder: (_) {
                final bh = _blockHeight(p.ev);
                final showTime = bh >= 34; // no room for the time line otherwise
                return Positioned(
                  top: (_toMin(p.ev['time'] as String?) / 60) * _hourPx + 1,
                  height: bh,
                  left: (p.col / p.cols) * w + 1,
                  width: w / p.cols - 2,
                  child: GestureDetector(
                    onTap: () => onEvent(p.ev),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        color: _colorFor(p.ev['color'] as String?),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((p.ev['title'] as String?) ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            if (showTime)
                              Text(_fmtTime(p.ev['time'] as String?),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            // "now" indicator line on today's column
            if (_key(day) == _key(DateTime.now()))
              Builder(builder: (_) {
                final now = DateTime.now();
                final top = ((now.hour * 60 + now.minute) / 60) * _hourPx;
                return Positioned(
                  top: top - 1,
                  left: 0,
                  right: 0,
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
                    ),
                    Expanded(
                        child: Container(height: 2, color: AppColors.danger)),
                  ]),
                );
              }),
          ],
        );
      }),
    );
  }

  double _blockHeight(Map<String, dynamic> e) {
    final start = _toMin(e['time'] as String?);
    final end = _toMin(e['endTime'] as String?);
    final dur = (end > start) ? end - start : 60;
    final h = (dur / 60) * _hourPx - 2;
    return h < 20 ? 20 : h; // keep tiny events tappable & readable
  }
}

class _Laid {
  final Map<String, dynamic> ev;
  final int col;
  final int cols;
  _Laid(this.ev, this.col, this.cols);
}

// Greedy column layout for overlapping timed events within a day.
List<_Laid> _layoutColumns(List<Map<String, dynamic>> evs) {
  final sorted = [...evs]..sort((a, b) =>
      _toMin(a['time'] as String?).compareTo(_toMin(b['time'] as String?)));
  final result = <_Laid>[];
  var cluster = <Map<String, dynamic>>[];
  var cols = <int>[]; // column index per cluster member (parallel list)
  var clusterEnd = -1;

  int endOf(Map<String, dynamic> e) {
    final s = _toMin(e['time'] as String?);
    final en = _toMin(e['endTime'] as String?);
    return en > s ? en : s + 60;
  }

  void flush() {
    final n = cluster.isEmpty ? 1 : (cols.reduce((a, b) => a > b ? a : b) + 1);
    for (var i = 0; i < cluster.length; i++) {
      result.add(_Laid(cluster[i], cols[i], n));
    }
    cluster = [];
    cols = [];
    clusterEnd = -1;
  }

  for (final ev in sorted) {
    final s = _toMin(ev['time'] as String?);
    if (cluster.isNotEmpty && s >= clusterEnd) flush();
    final used = <int>{};
    for (var i = 0; i < cluster.length; i++) {
      if (endOf(cluster[i]) > s) used.add(cols[i]);
    }
    var c = 0;
    while (used.contains(c)) c++;
    cluster.add(ev);
    cols.add(c);
    final e = endOf(ev);
    if (e > clusterEnd) clusterEnd = e;
  }
  flush();
  return result;
}

// ─── Search ───────────────────────────────────────────────────────────────
class _EventSearchDelegate extends SearchDelegate<void> {
  final void Function(Map<String, dynamic>) onPick;
  _EventSearchDelegate(this.onPick);

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    if (query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Search your events',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AppDb.instance.searchCalendarEvents(query),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching events',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        final df = DateFormat('EEE, d MMM yyyy');
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = items[i];
            final allDay = e['allDay'] == true;
            return ListTile(
              leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _colorFor(e['color'] as String?),
                    shape: BoxShape.circle),
              ),
              title: Text((e['title'] as String?) ?? ''),
              subtitle: Text(
                  '${df.format(e['date'] as DateTime)}'
                  '${allDay ? ' · All day' : ' · ${_fmtTime(e['time'] as String?)}'}'),
              onTap: () {
                close(context, null);
                onPick(e);
              },
            );
          },
        );
      },
    );
  }
}
