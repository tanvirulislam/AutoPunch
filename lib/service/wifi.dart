import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Android reports SSIDs wrapped in quotes, and `<unknown ssid>` when the
/// name is hidden (no location permission, location off, or not on Wi-Fi).
String? normalizeSsid(String? raw) {
  if (raw == null) return null;
  var ssid = raw.trim();
  if (ssid.length >= 2 && ssid.startsWith('"') && ssid.endsWith('"')) {
    ssid = ssid.substring(1, ssid.length - 1);
  }
  if (ssid.isEmpty || ssid == '<unknown ssid>') return null;
  return ssid;
}

class WifiService {
  static const _channel = MethodChannel('attendance/wifi');
  static final _info = NetworkInfo();

  /// The Wi-Fi name the phone is connected to right now, or null.
  static Future<String?> currentSsid() async {
    try {
      return normalizeSsid(await _info.getWifiName());
    } on PlatformException {
      return null;
    }
  }

  /// Asks Android to auto-connect to [ssid] whenever it is in range. The
  /// first time, Android shows a notification asking the user to allow it.
  /// Only works from the UI isolate (the channel lives in MainActivity).
  static Future<bool> addSuggestion(String ssid, String password) async {
    final ok = await _channel.invokeMethod<bool>(
      'addSuggestion',
      {'ssid': ssid, 'password': password},
    );
    return ok ?? false;
  }

  /// Opens the system location page (Android hides the Wi-Fi name while
  /// location is off).
  static Future<void> openLocationSettings() =>
      _channel.invokeMethod<bool>('openLocationSettings');
}
