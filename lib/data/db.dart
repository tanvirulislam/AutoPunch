import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the attendance database.
///
/// Both the UI isolate and the background tracker isolate call this. sqflite
/// shares one native connection per path across isolates in the same process,
/// so never call `close()` on it.
class AppDatabase {
  static Future<Database>? _db;

  static Future<Database> open() => _db ??= _open();

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'attendance.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE attendance(
            date      TEXT PRIMARY KEY,
            check_in  INTEGER,
            check_out INTEGER,
            status    TEXT NOT NULL DEFAULT 'present',
            manual    INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
  }
}
