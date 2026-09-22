import 'package:intl/intl.dart';

import '../models/day_record.dart';

final _dayFormat = DateFormat('dd MMM yyyy (EEE)');
final _timeFormat = DateFormat('hh:mm a');

String formatTime(DateTime? time) => time == null ? '--' : _timeFormat.format(time);

/// The status text for one day: its times, "Leave", "Off day" or "No record".
///
/// Leave wins over everything. Recorded times win over the weekend rule, so
/// working on an off day still shows the times.
String dayStatusText(DayRecord? record, DateTime day, Set<int> weekendDays) {
  if (record != null && record.isLeave) return 'Leave';
  if (record?.checkIn != null) {
    return '${formatTime(record!.checkIn)} - ${formatTime(record.checkOut)}';
  }
  if (weekendDays.contains(day.weekday)) return 'Off day';
  return 'No record';
}

/// Every calendar day from [from] to [to] inclusive, as local midnights.
List<DateTime> daysInRange(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return [
    // Build each date from its parts so DST changes never skip or repeat a day.
    for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) d,
  ];
}

/// Plain text for pasting elsewhere, one line per day, e.g.
/// `22 Sep 2026 (Tue): 09:30 AM - 07:00 PM`.
String formatRange({
  required Map<String, DayRecord> records,
  required DateTime from,
  required DateTime to,
  required Set<int> weekendDays,
}) {
  return daysInRange(from, to)
      .map((day) => '${_dayFormat.format(day)}: '
          '${dayStatusText(records[dateKey(day)], day, weekendDays)}')
      .join('\n');
}
