import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../logic/copy_formatter.dart';
import '../models/day_record.dart';

/// One month of days. Tap a day to fix its times, mark leave, or clear it.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, DayRecord> _records = {};
  Set<int> _weekendDays = {};

  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 0);

  @override
  void initState() {
    super.initState();
    dataChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final month = _month;
    final repo = await appRepo;
    final records = await repo.getRange(month, DateTime(month.year, month.month + 1, 0));
    final weekendDays = await repo.getWeekendDays();
    if (!mounted || month != _month) return;
    setState(() {
      _records = records;
      _weekendDays = weekendDays;
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Newest first, so today is at the top of the current month.
    final days = daysInRange(_month, _monthEnd).reversed.toList();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: days.length,
              itemBuilder: (context, i) => _dayTile(days[i], today),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayTile(DateTime day, DateTime today) {
    final record = _records[dateKey(day)];
    final isFuture = day.isAfter(today);
    final isToday = dateKey(day) == dateKey(today);
    var status = dayStatusText(record, day, _weekendDays);
    if (isFuture && status == 'No record') status = 'Upcoming';

    final IconData icon;
    if (record?.isLeave ?? false) {
      icon = Icons.beach_access;
    } else if (record?.checkIn != null) {
      icon = Icons.check_circle;
    } else if (_weekendDays.contains(day.weekday)) {
      icon = Icons.weekend;
    } else {
      icon = Icons.remove_circle_outline;
    }

    return ListTile(
      leading: Icon(icon, color: record?.checkIn != null ? Colors.green : null),
      title: Text(DateFormat('dd MMM yyyy (EEE)').format(day),
          style: isToday ? const TextStyle(fontWeight: FontWeight.bold) : null),
      subtitle: Text(status + ((record?.manual ?? false) && !record!.isLeave ? '  ·  edited' : '')),
      onTap: () => _showDayActions(day, record, isFuture),
    );
  }

  Future<void> _showDayActions(DateTime day, DayRecord? record, bool isFuture) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(DateFormat('EEEE, d MMMM yyyy').format(day)),
              subtitle: Text(dayStatusText(record, day, _weekendDays)),
            ),
            const Divider(height: 1),
            if (!isFuture)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit times'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            ListTile(
              leading: const Icon(Icons.beach_access),
              title: Text(record?.isLeave ?? false ? 'Remove leave' : 'Mark as leave'),
              onTap: () => Navigator.pop(context, 'leave'),
            ),
            if (record != null && !record.isLeave)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear day'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = await appRepo;
    switch (action) {
      case 'edit':
        await _editTimes(day, record);
      case 'leave':
        await repo.setLeave(day, !(record?.isLeave ?? false));
      case 'clear':
        await repo.clearDay(day);
    }
    notifyDataChanged();
  }

  Future<void> _editTimes(DateTime day, DayRecord? record) async {
    TimeOfDay initial(DateTime? time, int fallbackHour) =>
        time == null ? TimeOfDay(hour: fallbackHour, minute: 0) : TimeOfDay.fromDateTime(time);
    DateTime onDay(TimeOfDay t) => DateTime(day.year, day.month, day.day, t.hour, t.minute);

    final checkIn = await showTimePicker(
      context: context,
      helpText: 'CHECK-IN TIME',
      initialTime: initial(record?.checkIn, 9),
    );
    if (checkIn == null || !mounted) return;
    final checkOut = await showTimePicker(
      context: context,
      helpText: 'CHECK-OUT TIME',
      initialTime: initial(record?.checkOut, 18),
    );
    if (checkOut == null || !mounted) return;
    if (!onDay(checkOut).isAfter(onDay(checkIn))) {
      return _snack('Check-out must be after check-in');
    }
    await (await appRepo).editDay(day, onDay(checkIn), onDay(checkOut));
  }
}
