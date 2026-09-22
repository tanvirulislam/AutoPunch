import 'package:intl/intl.dart';

final _dateKeyFormat = DateFormat('yyyy-MM-dd');

/// The storage key for a calendar day in local time, e.g. `2026-09-22`.
String dateKey(DateTime day) => _dateKeyFormat.format(day);

/// Parses a [dateKey] back into a local midnight [DateTime].
DateTime parseDateKey(String key) => _dateKeyFormat.parse(key);

enum DayStatus { present, leave }

/// One attendance row per calendar day.
///
/// [checkIn] is the first time the phone was seen on the office Wi-Fi that
/// day and [checkOut] is the latest time it was seen there, so short
/// disconnects during the day never end the day early.
class DayRecord {
  const DayRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    this.status = DayStatus.present,
    this.manual = false,
  });

  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DayStatus status;

  /// True once the user has edited this day by hand. The background tracker
  /// never changes a manual day.
  final bool manual;

  bool get isLeave => status == DayStatus.leave;

  DayRecord copyWith({DateTime? checkIn, DateTime? checkOut}) => DayRecord(
    date: date,
    checkIn: checkIn ?? this.checkIn,
    checkOut: checkOut ?? this.checkOut,
    status: status,
    manual: manual,
  );

  Map<String, Object?> toMap() => {
    'date': date,
    'check_in': checkIn?.millisecondsSinceEpoch,
    'check_out': checkOut?.millisecondsSinceEpoch,
    'status': status.name,
    'manual': manual ? 1 : 0,
  };

  factory DayRecord.fromMap(Map<String, Object?> map) => DayRecord(
    date: map['date'] as String,
    checkIn: _fromMillis(map['check_in']),
    checkOut: _fromMillis(map['check_out']),
    status: DayStatus.values.byName(map['status'] as String),
    manual: map['manual'] == 1,
  );

  static DateTime? _fromMillis(Object? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch(value as int);
}
