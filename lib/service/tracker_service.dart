import 'dart:ui' show Color;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import 'tracker_task.dart';

/// How often the background service checks the Wi-Fi. This is also the
/// accuracy of the check-out time.
const checkInterval = Duration(minutes: 1);

/// Which of the settings needed for reliable background tracking are in place.
class TrackerPermissions {
  const TrackerPermissions({
    required this.location,
    required this.backgroundLocation,
    required this.locationServiceOn,
    required this.notifications,
    required this.batteryUnrestricted,
  });

  final bool location;
  final bool backgroundLocation;
  final bool locationServiceOn;
  final bool notifications;
  final bool batteryUnrestricted;

  bool get allGranted =>
      location && backgroundLocation && locationServiceOn && notifications && batteryUnrestricted;
}

class TrackerService {
  /// Configures the foreground service. Call once at app start.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'attendance_tracker',
        channelName: 'Attendance tracking',
        channelDescription: 'Shown while the app is tracking office check-in and check-out.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(checkInterval.inMilliseconds),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Starts tracking. Android refuses to start a location service without
  /// location permission, so check [permissions] first.
  static Future<ServiceRequestResult> start() async {
    if (await isRunning) return FlutterForegroundTask.restartService();
    return FlutterForegroundTask.startService(
      serviceId: 300,
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: 'Attendance tracking',
      notificationText: 'Checking office Wi-Fi…',
      // Declared as meta-data in AndroidManifest.xml. Later notification
      // updates and restarts after reboot keep this icon.
      notificationIcon: const NotificationIcon(
        metaDataName: 'autopunch.NOTIFICATION_ICON',
        backgroundColor: Color(0xFF00897B),
      ),
      notificationInitialRoute: '/',
      callback: startCallback,
    );
  }

  static Future<ServiceRequestResult> stop() => FlutterForegroundTask.stopService();

  /// Asks the running service to check the Wi-Fi right away.
  static void checkNow() => FlutterForegroundTask.sendDataToTask(checkNowMessage);

  static Future<TrackerPermissions> permissions() async => TrackerPermissions(
    location: await Permission.locationWhenInUse.isGranted,
    backgroundLocation: await Permission.locationAlways.isGranted,
    locationServiceOn: await Permission.location.serviceStatus.isEnabled,
    notifications:
        await FlutterForegroundTask.checkNotificationPermission() == NotificationPermission.granted,
    batteryUnrestricted: await FlutterForegroundTask.isIgnoringBatteryOptimizations,
  );

  /// Location while in use must be granted before "Allow all the time".
  static Future<void> requestLocation() => Permission.locationWhenInUse.request();

  /// Opens the system page where the user picks "Allow all the time".
  /// Android ignores this request until "while in use" is granted.
  static Future<void> requestBackgroundLocation() async {
    if (!await Permission.locationWhenInUse.request().isGranted) return;
    await Permission.locationAlways.request();
  }

  static Future<void> requestNotifications() => FlutterForegroundTask.requestNotificationPermission();

  static Future<void> requestBatteryUnrestricted() =>
      FlutterForegroundTask.requestIgnoreBatteryOptimization();
}
