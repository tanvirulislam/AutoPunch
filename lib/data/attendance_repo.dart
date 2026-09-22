import 'package:sqflite/sqflite.dart';

import '../logic/attendance_logic.dart';
import '../models/day_record.dart';
import 'db.dart';

/// Dart weekday numbers (Mon = 1 ... Sun = 7). Friday and Saturday by default.
const defaultWeekendDays = {DateTime.friday, DateTime.saturday};

class AttendanceRepo {
  AttendanceRepo(this._db);

  final Database _db;

  static Future<AttendanceRepo> open() async => AttendanceRepo(await AppDatabase.open());

  // ---- Attendance -------------------------------------------------------

  Future<DayRecord?> getDay(DateTime day) => _getDay(_db, dateKey(day));

  static Future<DayRecord?> _getDay(DatabaseExecutor db, String key) async {
    final rows = await db.query('attendance', where: 'date = ?', whereArgs: [key]);
    return rows.isEmpty ? null : DayRecord.fromMap(rows.first);
  }

  /// Records that the phone is on the office Wi-Fi at [now] and returns
  /// today's record afterwards. See [applySeen] for the rules.
  ///
  /// Uses select + insert/update instead of an upsert, because Android 10
  /// ships SQLite 3.22, which predates `ON CONFLICT DO UPDATE`.
  Future<DayRecord> markSeen(DateTime now) {
    return _db.transaction((txn) async {
      final existing = await _getDay(txn, dateKey(now));
      final updated = applySeen(existing, now);
      if (updated == null) return existing!;
      if (existing == null) {
        await txn.insert('attendance', updated.toMap());
      } else {
        await txn.update('attendance', updated.toMap(),
            where: 'date = ?', whereArgs: [updated.date]);
      }
      return updated;
    });
  }

  /// All stored records between [from] and [to] inclusive, keyed by [dateKey].
  Future<Map<String, DayRecord>> getRange(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'attendance',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [dateKey(from), dateKey(to)],
    );
    return {for (final row in rows) row['date'] as String: DayRecord.fromMap(row)};
  }

  /// Marks [day] as leave, replacing any times. Unmarking removes the day.
  Future<void> setLeave(DateTime day, bool leave) async {
    if (!leave) return clearDay(day);
    await _put(DayRecord(date: dateKey(day), status: DayStatus.leave, manual: true));
  }

  /// Sets the times for [day] by hand. The tracker will not change it again.
  Future<void> editDay(DateTime day, DateTime checkIn, DateTime? checkOut) =>
      _put(DayRecord(date: dateKey(day), checkIn: checkIn, checkOut: checkOut, manual: true));

  /// Deletes [day]. If the phone is still on the office Wi-Fi today, the
  /// tracker starts a fresh record on its next check.
  Future<void> clearDay(DateTime day) =>
      _db.delete('attendance', where: 'date = ?', whereArgs: [dateKey(day)]);

  Future<void> _put(DayRecord record) =>
      _db.insert('attendance', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // ---- Settings ---------------------------------------------------------

  Future<String?> getTargetSsid() => _getSetting('target_ssid');

  Future<void> setTargetSsid(String ssid) => _setSetting('target_ssid', ssid);

  Future<Set<int>> getWeekendDays() async {
    final value = await _getSetting('weekend_days');
    if (value == null) return defaultWeekendDays;
    if (value.isEmpty) return {};
    return value.split(',').map(int.parse).toSet();
  }

  Future<void> setWeekendDays(Set<int> days) =>
      _setSetting('weekend_days', (days.toList()..sort()).join(','));

  Future<String?> _getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _setSetting(String key, String value) => _db.insert(
    'settings',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
