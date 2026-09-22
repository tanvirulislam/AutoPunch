import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/logic/attendance_logic.dart';
import 'package:test_app/models/day_record.dart';

void main() {
  DateTime at(int hour, int minute, {int day = 22}) => DateTime(2026, 9, day, hour, minute);

  test('first sample of the day sets check-in and check-out', () {
    final record = applySeen(null, at(9, 30))!;
    expect(record.date, '2026-09-22');
    expect(record.checkIn, at(9, 30));
    expect(record.checkOut, at(9, 30));
    expect(record.manual, isFalse);
  });

  test('later samples only move check-out forward', () {
    final first = applySeen(null, at(9, 30))!;
    final later = applySeen(first, at(12, 0))!;
    expect(later.checkIn, at(9, 30));
    expect(later.checkOut, at(12, 0));
  });

  test('a disconnect and reconnect mid-day keeps the original check-in', () {
    var record = applySeen(null, at(9, 30))!;
    record = applySeen(record, at(13, 0))!;
    // Wi-Fi drops 13:00-13:20: no samples are recorded in the gap.
    record = applySeen(record, at(13, 20))!;
    record = applySeen(record, at(19, 0))!;
    expect(record.checkIn, at(9, 30));
    expect(record.checkOut, at(19, 0));
  });

  test('check-out stays at the last sample once the phone leaves', () {
    var record = applySeen(null, at(9, 30))!;
    record = applySeen(record, at(18, 59))!;
    // No further samples after leaving the office.
    expect(record.checkOut, at(18, 59));
  });

  test('manual and leave days are never changed', () {
    final manual = DayRecord(date: '2026-09-22', checkIn: at(9, 0), checkOut: at(17, 0), manual: true);
    expect(applySeen(manual, at(18, 0)), isNull);

    const leave = DayRecord(date: '2026-09-22', status: DayStatus.leave, manual: true);
    expect(applySeen(leave, at(10, 0)), isNull);
  });

  test('samples that are not newer are ignored', () {
    final record = applySeen(applySeen(null, at(9, 30)), at(12, 0))!;
    expect(applySeen(record, at(11, 0)), isNull);
    expect(applySeen(record, at(12, 0)), isNull);
  });

  test('a new date starts a new record', () {
    final monday = applySeen(null, at(18, 0, day: 21))!;
    final tuesday = applySeen(null, at(9, 15, day: 22))!;
    expect(monday.date, '2026-09-21');
    expect(tuesday.date, '2026-09-22');
    expect(tuesday.checkIn, at(9, 15, day: 22));
  });
}
