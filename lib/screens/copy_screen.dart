import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../logic/copy_formatter.dart';

/// Pick a date range and copy its check-in/check-out times as plain text.
class CopyScreen extends StatefulWidget {
  const CopyScreen({super.key});

  @override
  State<CopyScreen> createState() => _CopyScreenState();
}

class _CopyScreenState extends State<CopyScreen> {
  late DateTimeRange _range = _thisMonth();
  String _text = '';

  static final _rangeFormat = DateFormat('dd MMM yyyy');

  static DateTimeRange _thisMonth() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month, now.day));
  }

  static DateTimeRange _lastMonth() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month - 1),
      end: DateTime(now.year, now.month, 0),
    );
  }

  int get _dayCount => daysInRange(_range.start, _range.end).length;

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
    final range = _range;
    final repo = await appRepo;
    final records = await repo.getRange(range.start, range.end);
    final weekendDays = await repo.getWeekendDays();
    if (!mounted || range != _range) return;
    setState(() {
      _text = formatRange(
        records: records,
        from: range.start,
        to: range.end,
        weekendDays: weekendDays,
      );
    });
  }

  void _setRange(DateTimeRange range) {
    setState(() => _range = range);
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
    );
    if (picked != null) _setRange(picked);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $_dayCount ${_dayCount == 1 ? 'day' : 'days'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range),
              label: Text('${_rangeFormat.format(_range.start)}  –  ${_rangeFormat.format(_range.end)}'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('This month'), onPressed: () => _setRange(_thisMonth())),
                ActionChip(label: const Text('Last month'), onPressed: () => _setRange(_lastMonth())),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(_text, style: const TextStyle(height: 1.6)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _text.isEmpty ? null : _copy,
              icon: const Icon(Icons.copy),
              label: Text('Copy $_dayCount ${_dayCount == 1 ? 'day' : 'days'}'),
            ),
          ],
        ),
      ),
    );
  }
}
