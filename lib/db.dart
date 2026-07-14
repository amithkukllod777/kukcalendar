import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Minimal local datastore for the standalone Kuk Calendar app. All calendar
/// data (events, tasks, calendars) lives in one SQLite file.
///
/// Schema strategy: instead of a version/onUpgrade ladder, the tables and any
/// new columns are applied idempotently on demand by the extensions in
/// db_calendar.dart (CREATE TABLE IF NOT EXISTS + additive ALTERs). This is a
/// valid forward-only migration approach — a fresh install and an upgraded one
/// converge to the same schema. Expected "duplicate column" ALTER errors are
/// ignored; any other DB error is logged rather than silently swallowed
/// (qa-audit DATA-2). Bump to a real onUpgrade ladder only if a destructive or
/// data-transforming migration is ever needed.
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
