# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read this whole file before starting any task.** When you finish a piece of work, update the [Status](#status) section so the next session knows what is done and what is left.

## What the app is

AutoPunch is an Android-only Flutter app that records office attendance from Wi-Fi:

1. The user picks the office Wi-Fi. The app registers it as a Wi-Fi network suggestion, so Android auto-connects whenever it is in range.
2. A foreground service checks the connected SSID every minute. **Check-in** is the first time the phone is seen on the office Wi-Fi that day. **Check-out** is the last time it was seen. A disconnect is never treated as check-out, so drops and reconnects during the day don't end the day early. Missed events (app killed, reboot, dead battery) also can't corrupt a record.
3. The user can edit a day's times, mark leave, or clear a day. Edited days are locked (`manual = 1`) and the tracker never changes them again. "Clear day" re-enables automatic tracking.
4. The Copy tab exports a date range as readable text, one line per day, e.g. `22 Sep 2026 (Tue): 09:30 AM - 07:00 PM`. Each day's label is chosen in this order: **Leave**, then recorded times, then **Off day** (weekly off days: Fri and Sat by default, configurable), then **No record**.

iOS is intentionally unsupported because it doesn't allow background Wi-Fi monitoring. The `ios/`, `macos/`, `linux/`, `windows/` and `web/` folders are untouched Flutter template.

## Commands

```bash
flutter pub get
flutter analyze                     # lint (flutter_lints); must report "No issues found!"
flutter test                        # all unit tests
flutter test test/copy_formatter_test.dart                    # one file
flutter test --plain-name "a new date starts a new record"    # one test by name
flutter build apk --debug           # also checks the Kotlin code, manifest and vector drawables
flutter run                         # needs an Android device/emulator (none on this machine as of 2026-09-22)
```

To check the tracking rule on an emulator: the emulator's Wi-Fi SSID is `AndroidWifi`. Toggle it with `adb shell svc wifi disable` / `adb shell svc wifi enable`, then confirm check-in stays fixed while check-out advances.

## Architecture

### Two isolates, one database
- **UI isolate:** `lib/main.dart` → `HomeShell`, which has three tabs in `lib/screens/` (Today, History, Copy).
- **Service isolate:** `flutter_foreground_task` starts a separate Flutter engine that runs `startCallback` → `TrackerTaskHandler` (`lib/service/tracker_task.dart`). Every `checkInterval` (1 min) the handler reads the SSID, calls `AttendanceRepo.markSeen`, and updates the notification text.

The two isolates share no memory. They communicate through:
- **sqflite** (`lib/data/db.dart`, file `attendance.db`). On Android, sqflite keeps one static native connection per path, shared by both engines. Never call `close()` on it.
- **Settings in the database.** The office SSID and weekend days live in the `settings` table, not in shared_preferences, because shared_preferences caches values per isolate.
- **Service → UI:** `FlutterForegroundTask.sendDataToMain` → `HomeShell._onTaskData` → `notifyDataChanged()` (`lib/app_state.dart`). Every screen listens to `dataChanged` and re-queries. UI edits and app resume also call `notifyDataChanged()`.
- **UI → service:** `TrackerService.checkNow()` sends `checkNowMessage` to trigger an immediate check.

### Where the rules live
- **Check-in/check-out rule:** `applySeen` in `lib/logic/attendance_logic.dart`. It is a pure function with unit tests.
- **Applying the rule:** `AttendanceRepo.markSeen` applies `applySeen` inside a transaction, using select then insert/update. Android 10 ships SQLite 3.22, which has no `ON CONFLICT DO UPDATE`.
- **Day labels:** `dayStatusText` and `formatRange` in `lib/logic/copy_formatter.dart`. Both the History and Copy screens use them.
- **Row format:** rows are keyed by local date `yyyy-MM-dd` (`dateKey`), and times are stored as epoch milliseconds. Leave rows have `status = 'leave'`, no times, and `manual = 1`.
- **Known limitation:** a shift past midnight splits into two dates.

### Native Android pieces
- **Wi-Fi channel:** `MainActivity.kt` exposes the MethodChannel `attendance/wifi` with two methods:
  - `addSuggestion(ssid, password)` registers a WifiNetworkSuggestion: WPA2, plus WPA3 if the phone supports it. It replaces any earlier suggestion.
  - `openLocationSettings` opens the system location page.

  The channel exists only in the UI engine. Don't call it from the service isolate.
- **Reading the SSID:** the SSID comes from `network_info_plus`. Android returns it wrapped in quotes, or as `<unknown ssid>` when location permission is missing or location is off. Always go through `normalizeSsid` (`lib/service/wifi.dart`).
- **Foreground service:** the service type is `location` (set in the manifest).
  - Android refuses to start it without location permission.
  - Restarting after a reboot also needs "Allow all the time" location (ACCESS_BACKGROUND_LOCATION).
  - The Today screen's setup checklist requests these permissions through `TrackerService`.
- **Notification icon:** the manifest meta-data `autopunch.NOTIFICATION_ICON` points to `@drawable/ic_notification`. It is passed only in `TrackerService.start()`, and the plugin keeps it across notification updates and reboots.
- **Launcher icon:** an adaptive icon in `res/mipmap-anydpi-v26/ic_launcher.xml` with vector background and foreground layers. The foreground doubles as the Android 13 monochrome (themed-icon) layer.
  - The editable source is `assets/icon/autopunch_icon.svg`, drawn on the 108×108 adaptive-icon canvas. Keep artwork inside the central 66-unit circle.
  - The legacy `mipmap-*/ic_launcher.png` files are rendered from that SVG with ImageMagick.

## Version constraints (don't "fix" these blindly)
- **`minSdk = 29`:** required by WifiNetworkSuggestion.
- **`permission_handler` is pinned to `^12.0.1`.** Version 13.x pulls in `permission_handler_android` 14.x, which needs compileSdk 37. That is newer than the AGP 9.1.0 used here supports, so upgrade AGP first.
- **`flutter_foreground_task` 11.x needs Kotlin ≥ 2.2.20 and Gradle ≥ 8.11.1.** The project uses AGP 9.1.0, Kotlin 2.4.0 and Gradle 9.3.1.
- **The application ID and Kotlin package are still the template's `com.example.test_app`.** Changing the ID makes Android treat the app as a new install, and existing attendance data doesn't carry over. Change it only when asked, and before real use.

## Status
_Last updated: 2026-09-22_

### Done
- The full app as described above: tracking service, auto-connect, Today/History/Copy screens, leave and weekly off days, readable-text copy.
- App name **AutoPunch**, with a custom launcher icon and notification icon.
- 14 unit tests in `test/` pass, `flutter analyze` is clean, and the debug APK builds.
- Local git repo on `main` with the initial commit.

### To do
- **Push to GitHub** as the public repo `autopunch`.
  - Waiting for the user to run `sudo dnf install gh` and `gh auth login`.
  - Before pushing, ask whether commits should use the GitHub no-reply email instead of the work email, since the repo is public.
  - Then run `gh repo create autopunch --public --source=. --push`.
- **On-device testing hasn't been done** because no device or emulator is available. Check:
  - Check-in appears within a minute.
  - Turning Wi-Fi off and on keeps check-in and advances check-out.
  - Tracking survives swiping the app away and a reboot.
  - History edits aren't overwritten by the tracker.
  - Copy output has the right labels.
  - The auto-connect prompt appears on a real phone.
- **Offered but not yet requested:**
  - Change the application ID (e.g. `com.<org>.autopunch`).
  - Replace the template README.
  - Export a 512 px Play Store icon from the SVG.
- **Release signing:** release builds are still signed with the debug key (`android/app/build.gradle.kts`). They need a real signing config before publishing to the Play Store.
