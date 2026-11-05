import 'package:flutter/material.dart';

import '../models/schedule_dialog_host.dart';
import '../models/schedule_entry.dart';
import '../theme/app_strings.dart';

export '../models/schedule_dialog_host.dart';

Future<void> showScheduleDialog(BuildContext context, ScheduleDialogHost host) {
  return showDialog<void>(
    context: context,
    builder: (_) => ScheduleDialog(host: host),
  );
}

class ScheduleDialog extends StatefulWidget {
  final ScheduleDialogHost host;

  const ScheduleDialog({super.key, required this.host});

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _weekdays = {...ScheduleEntry.everyDay};

  ScheduleDialogHost get _host => widget.host;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _host.listenable,
      builder: (context, _) {
        final entries = _host.entries();
        return AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text(AppStrings.scheduleTitle)),
              IconButton(
                key: const Key('schedule-sync'),
                tooltip: AppStrings.scheduleSync,
                onPressed: _host.canSync() ? _host.onSync : null,
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(AppStrings.scheduleHelp),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(AppStrings.scheduleEmpty),
                    ),
                  for (final entry in entries)
                    ScheduleEntryTile(entry: entry, host: _host),
                  const Divider(height: 24),
                  const Text(AppStrings.scheduleAddTitle),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('schedule-time'),
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(_time.format(context)),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      key: const Key('schedule-add'),
                      onPressed: _host.canAdd() && _weekdays.isNotEmpty
                          ? () => _host.onAdd(_time.hour, _time.minute, {
                              ..._weekdays,
                            })
                          : null,
                      child: const Text(AppStrings.scheduleAdd),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.close),
            ),
          ],
        );
      },
    );
  }
}

/// 予定1件の行（時刻・曜日・有効切替・削除）。ダイアログと予定タブで共有する。
class ScheduleEntryTile extends StatelessWidget {
  const ScheduleEntryTile({super.key, required this.entry, required this.host});

  final ScheduleEntry entry;
  final ScheduleDialogHost host;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('schedule-entry-${entry.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(entry.timeText),
      subtitle: Text(AppStrings.weekdaysText(entry.weekdays)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            key: Key('schedule-toggle-${entry.id}'),
            value: entry.enabled,
            onChanged: (on) => host.onToggle(entry.id, on),
          ),
          IconButton(
            key: Key('schedule-delete-${entry.id}'),
            tooltip: AppStrings.scheduleDeleteTooltip,
            onPressed: () => host.onDelete(entry.id),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
