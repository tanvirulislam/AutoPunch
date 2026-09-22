import 'package:flutter_test/flutter_test.dart';
import 'package:autopunch/data/attendance_repo.dart';
import 'package:autopunch/logic/copy_formatter.dart';
import 'package:autopunch/models/day_record.dart';

void main() {
  DateTime d(int day, [int hour = 0, int minute = 0]) => DateTime(2026, 9, day, hour, minute);

  DayRecord present(int day, int inH, int inM, int outH, int outM) =>
      DayRecord(date: dateKey(d(day)), checkIn: d(day, inH, inM), checkOut: d(day, outH, outM));

  test('formats every day in the range with the right label', () {
    // 22 Sep 2026 is a Tuesday; 25/26 are Fri/Sat.
    final records = {
      '2026-09-22': present(22, 9, 30, 19, 0),
      '2026-09-23': present(23, 9, 12, 18, 45),
      '2026-09-27': const DayRecord(date: '2026-09-27', status: DayStatus.leave, manual: true),
    };
    final text = formatRange(
      records: records,
      from: d(22),
      to: d(28),
      weekendDays: defaultWeekendDays,
    );
    expect(text.split('\n'), [
      '22 Sep 2026 (Tue): 09:30 AM - 07:00 PM',
      '23 Sep 2026 (Wed): 09:12 AM - 06:45 PM',
      '24 Sep 2026 (Thu): No record',
      '25 Sep 2026 (Fri): Off day',
      '26 Sep 2026 (Sat): Off day',
      '27 Sep 2026 (Sun): Leave',
      '28 Sep 2026 (Mon): No record',
    ]);
  });

  test('working on an off day shows the times', () {
    final friday = present(25, 10, 0, 14, 0);
    expect(dayStatusText(friday, d(25), defaultWeekendDays), '10:00 AM - 02:00 PM');
  });

  test('leave on an off day still shows Leave', () {
    const leave = DayRecord(date: '2026-09-25', status: DayStatus.leave, manual: true);
    expect(dayStatusText(leave, d(25), defaultWeekendDays), 'Leave');
  });

  test('custom weekend days are respected', () {
    expect(dayStatusText(null, d(27), {DateTime.sunday}), 'Off day');
    expect(dayStatusText(null, d(25), {DateTime.sunday}), 'No record');
  });

  test('range is inclusive, ignores time of day, and a single day works', () {
    expect(daysInRange(d(22, 18), d(22, 9)), [d(22)]);
    expect(daysInRange(d(29), DateTime(2026, 10, 2)).length, 4);
    expect(formatRange(records: {}, from: d(24), to: d(24), weekendDays: {}),
        '24 Sep 2026 (Thu): No record');
  });

  test('missing check-out shows a placeholder', () {
    final record = DayRecord(date: '2026-09-22', checkIn: d(22, 9, 5));
    expect(dayStatusText(record, d(22), {}), '09:05 AM - --');
  });
}
