import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../logic/copy_formatter.dart';
import '../models/day_record.dart';
import '../service/tracker_service.dart';
import '../service/wifi.dart';

/// Status, office Wi-Fi setup, permissions and off-day settings.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loaded = false;
  String? _targetSsid;
  String? _currentSsid;
  DayRecord? _today;
  Set<int> _weekendDays = {};
  TrackerPermissions? _permissions;
  bool _running = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    dataChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataChanged.removeListener(_load);
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = await appRepo;
    final target = await repo.getTargetSsid();
    final today = await repo.getDay(DateTime.now());
    final weekendDays = await repo.getWeekendDays();
    final permissions = await TrackerService.permissions();
    final running = await TrackerService.isRunning;
    final current = await WifiService.currentSsid();
    if (!mounted) return;
    setState(() {
      if (!_loaded) _ssidController.text = target ?? '';
      _loaded = true;
      _targetSsid = target;
      _today = today;
      _weekendDays = weekendDays;
      _permissions = permissions;
      _running = running;
      _currentSsid = current;
    });
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _saveWifi() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;
    if (ssid.isEmpty) return _snack('Enter the office Wi-Fi name');
    setState(() => _saving = true);
    try {
      await (await appRepo).setTargetSsid(ssid);
      String message = 'Office Wi-Fi saved';
      if (password.isNotEmpty) {
        final ok = await WifiService.addSuggestion(ssid, password);
        message = ok
            ? 'Saved. Allow the Android prompt so the phone auto-connects.'
            : 'Saved, but Android refused the auto-connect request.';
      }
      _passwordController.clear();
      if (_running) TrackerService.checkNow();
      if (mounted) _snack(message);
      notifyDataChanged();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleTracking(bool on) async {
    if (on) {
      if (_targetSsid == null) return _snack('Save the office Wi-Fi first');
      if (!(_permissions?.location ?? false)) {
        await TrackerService.requestLocation();
        if (!(await TrackerService.permissions()).location) {
          if (mounted) _snack('Location permission is needed to read the Wi-Fi name');
          return;
        }
      }
      final result = await TrackerService.start();
      if (result is ServiceRequestFailure && mounted) {
        _snack('Could not start tracking: ${result.error}');
      }
    } else {
      await TrackerService.stop();
    }
    notifyDataChanged();
  }

  Future<void> _toggleWeekend(int weekday, bool selected) async {
    final days = {..._weekendDays};
    selected ? days.add(weekday) : days.remove(weekday);
    await (await appRepo).setWeekendDays(days);
    notifyDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusCard(context),
            const SizedBox(height: 12),
            _trackingCard(),
            const SizedBox(height: 12),
            _permissionsCard(),
            const SizedBox(height: 12),
            _wifiCard(),
            const SizedBox(height: 12),
            _offDaysCard(context),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final atOffice = _targetSsid != null && _currentSsid == _targetSsid;
    final today = _today;
    final String todayText;
    if (today == null || (today.checkIn == null && !today.isLeave)) {
      todayText = 'No check-in yet today';
    } else if (today.isLeave) {
      todayText = 'Marked as leave';
    } else {
      todayText = 'Check-in ${formatTime(today.checkIn)}  ·  '
          '${atOffice ? 'last seen' : 'check-out'} ${formatTime(today.checkOut)}';
    }
    return Card(
      color: atOffice ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              _targetSsid == null
                  ? 'Office Wi-Fi not set'
                  : atOffice
                      ? 'At office'
                      : 'Not at office',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(todayText),
            const SizedBox(height: 4),
            Text(
              'Connected to: ${_currentSsid ?? 'unknown (needs Wi-Fi, location permission and location on)'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackingCard() {
    return Card(
      child: SwitchListTile(
        title: const Text('Background tracking'),
        subtitle: Text(
          'Checks the office Wi-Fi every ${checkInterval.inMinutes} min, '
          'even when the app is closed',
        ),
        value: _running,
        onChanged: _toggleTracking,
      ),
    );
  }

  Widget _permissionsCard() {
    final p = _permissions!;
    Widget item(String title, String why, bool ok, VoidCallback onFix, [String fix = 'Allow']) {
      return ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? Colors.green : Colors.orange),
        title: Text(title),
        subtitle: ok ? null : Text(why),
        trailing: ok ? null : TextButton(onPressed: onFix, child: Text(fix)),
      );
    }

    Future<void> Function() refreshAfter(Future<void> Function() action) => () async {
      await action();
      notifyDataChanged();
    };

    return Card(
      child: ExpansionTile(
        initiallyExpanded: !p.allGranted,
        title: const Text('Setup checklist'),
        subtitle: Text(p.allGranted ? 'Everything is set' : 'Some settings need attention'),
        children: [
          item('Location permission', 'Android hides the Wi-Fi name without it', p.location,
              refreshAfter(TrackerService.requestLocation)),
          item('Location: Allow all the time', 'Keeps tracking after a reboot or in the background',
              p.backgroundLocation, refreshAfter(TrackerService.requestBackgroundLocation)),
          item('Location turned on', 'Android hides the Wi-Fi name while location is off',
              p.locationServiceOn, WifiService.openLocationSettings, 'Open'),
          item('Notifications', 'Shows the tracking notification', p.notifications,
              refreshAfter(TrackerService.requestNotifications)),
          item('No battery restriction', 'Stops Android from killing the tracker',
              p.batteryUnrestricted, refreshAfter(TrackerService.requestBatteryUnrestricted)),
        ],
      ),
    );
  }

  Widget _wifiCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Office Wi-Fi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _ssidController,
              decoration: InputDecoration(
                labelText: 'Wi-Fi name (SSID)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Use current Wi-Fi',
                  icon: const Icon(Icons.my_location),
                  onPressed: () async {
                    final ssid = await WifiService.currentSsid();
                    if (!mounted) return;
                    if (ssid == null) {
                      _snack('Not connected, or location permission/location is off');
                    } else {
                      _ssidController.text = ssid;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (for auto-connect)',
                helperText: 'Leave empty if the phone already remembers this network',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _saveWifi,
              icon: const Icon(Icons.save),
              label: const Text('Save & auto-connect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offDaysCard(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly off days', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
                  FilterChip(
                    label: Text(names[weekday - 1]),
                    selected: _weekendDays.contains(weekday),
                    onSelected: (selected) => _toggleWeekend(weekday, selected),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
