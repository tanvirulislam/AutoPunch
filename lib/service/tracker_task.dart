import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/attendance_repo.dart';
import '../logic/copy_formatter.dart';
import 'wifi.dart';

/// Message the UI sends to ask for an immediate check (e.g. after changing
/// the office Wi-Fi).
const checkNowMessage = 'check_now';

/// Entry point of the background service isolate. Must stay top-level.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TrackerTaskHandler());
}

/// Runs in the foreground service. Every minute it checks whether the phone
/// is on the office Wi-Fi and, if so, extends today's check-out time.
class TrackerTaskHandler extends TaskHandler {
  AttendanceRepo? _repo;
  bool _checking = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) => _check();

  @override
  void onRepeatEvent(DateTime timestamp) => _check();

  @override
  void onReceiveData(Object data) {
    if (data == checkNowMessage) _check();
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/');

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final repo = _repo ??= await AttendanceRepo.open();
      final target = await repo.getTargetSsid();
      final ssid = await WifiService.currentSsid();
      final now = DateTime.now();
      final atOffice = target != null && ssid == target;

      final String title;
      final String text;
      if (target == null) {
        title = 'Attendance tracking';
        text = 'Office Wi-Fi is not set';
      } else if (atOffice) {
        final today = await repo.markSeen(now);
        title = today.isLeave ? 'On office Wi-Fi' : 'Checked in';
        text = today.isLeave
            ? 'Today is marked as leave'
            : 'Since ${formatTime(today.checkIn)} · last seen ${formatTime(today.checkOut)}';
      } else {
        final today = await repo.getDay(now);
        title = 'Not on $target';
        text = today?.checkIn == null
            ? 'Waiting for office Wi-Fi'
            : 'Today ${formatTime(today!.checkIn)} - ${formatTime(today.checkOut)}';
      }
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      FlutterForegroundTask.sendDataToMain({'ssid': ssid, 'atOffice': atOffice});
    } finally {
      _checking = false;
    }
  }
}
