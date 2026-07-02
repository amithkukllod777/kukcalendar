import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Minimal local datastore for the standalone Kuk Calendar app. All calendar
/// data (events, tasks, calendars) lives in one SQLite file; the tables are
/// created on demand by the extensions in db_calendar.dart
/// (CREATE TABLE IF NOT EXISTS), so there is no central migration.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db async {
    if (_db != null) return _db!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'kukcalendar.db');
    final d = await openDatabase(path, version: 1);
    _db = d;
    _opening = null;
    return d;
  }
}
