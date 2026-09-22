import '../models/day_record.dart';

/// Applies one "the phone is on the office Wi-Fi at [now]" sample to today's
/// record and returns the updated record, or null when nothing should change.
///
/// [existing] must be the record for `dateKey(now)`, or null if there is none.
///
/// - No record yet: this is the check-in, so check-in and check-out are both [now].
/// - Record exists: only check-out moves forward to [now]. Check-in never
///   changes, so a drop and reconnect in the middle of the day has no effect.
/// - Manual or leave days are never touched.
DayRecord? applySeen(DayRecord? existing, DateTime now) {
  if (existing == null) {
    return DayRecord(date: dateKey(now), checkIn: now, checkOut: now);
  }
  assert(existing.date == dateKey(now), 'record is for a different day');
  if (existing.manual || existing.isLeave) return null;
  final lastSeen = existing.checkOut;
  // Ignore samples that are not newer, e.g. after the clock was set back.
  if (lastSeen != null && !now.isAfter(lastSeen)) return null;
  return existing.copyWith(checkIn: existing.checkIn ?? now, checkOut: now);
}
