import 'package:flutter/foundation.dart';

import 'data/attendance_repo.dart';

/// The UI isolate's repository (the background service opens its own).
final Future<AttendanceRepo> appRepo = AttendanceRepo.open();

/// Bumped whenever attendance data or settings may have changed, so every
/// screen reloads: after a background check, an edit, or the app resuming.
final dataChanged = ValueNotifier<int>(0);

void notifyDataChanged() => dataChanged.value++;
