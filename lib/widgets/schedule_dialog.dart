import 'package:flutter/material.dart';

import '../models/cleaning_schedule.dart';
import '../theme/app_strings.dart';

/// 定時清掃ダイアログの操作結果。
sealed class ScheduleDialogResult {
  const ScheduleDialogResult();
}

class ScheduleReserve extends ScheduleDialogResult {
  final TimeOfDay time;
  final Set<int> weekdays;

  const ScheduleReserve({required this.time, required this.weekdays});
}

class ScheduleCancel extends ScheduleDialogResult {
  const ScheduleCancel();
}

/// 開始時刻と曜日を選び、予約または解除を返すダイアログ。
Future<ScheduleDialogResult?> showScheduleDialog(
  BuildContext context, {
  required bool canReserve,
  required bool canCancel,
}) {
  return showDialog<ScheduleDialogResult>(
    context: context,
    builder: (_) =>
        ScheduleDialog(canReserve: canReserve, canCancel: canCancel),
  );
}

class ScheduleDialog extends StatefulWidget {
  final bool canReserve;
  final bool canCancel;

  const ScheduleDialog({
    super.key,
    required this.canReserve,
    required this.canCancel,
  });

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _weekdays = {...CleaningScheduleMission.everyDay};

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.scheduleTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.scheduleHelp),
            const SizedBox(height: 16),
            const Text(AppStrings.scheduleTimeLabel),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('schedule-time'),
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(_time.format(context)),
            ),
            const SizedBox(height: 16),
            const Text(AppStrings.scheduleWeekdaysLabel),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    key: Key('schedule-weekday-${i + 1}'),
                    label: Text(AppStrings.weekdayLabels[i]),
                    selected: _weekdays.contains(i + 1),
                    onSelected: (on) => setState(() {
                      on ? _weekdays.add(i + 1) : _weekdays.remove(i + 1);
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          key: const Key('schedule-cancel'),
          onPressed: widget.canCancel
              ? () => Navigator.pop(context, const ScheduleCancel())
              : null,
          child: const Text(AppStrings.scheduleCancelAction),
        ),
        FilledButton(
          key: const Key('schedule-reserve'),
          onPressed: widget.canReserve && _weekdays.isNotEmpty
              ? () => Navigator.pop(
                  context,
                  ScheduleReserve(time: _time, weekdays: {..._weekdays}),
                )
              : null,
          child: const Text(AppStrings.scheduleReserve),
        ),
      ],
    );
  }
}
