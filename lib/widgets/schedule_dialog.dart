import 'package:flutter/material.dart';

import '../models/schedule_entry.dart';
import '../theme/app_strings.dart';

/// 予定ダイアログが画面の外（Controller）とやり取りするための窓口。
/// Widget を Controller に直接依存させないため、必要な読み書きだけを束ねる。
class ScheduleDialogHost {
  const ScheduleDialogHost({
    required this.listenable,
    required this.entries,
    required this.canAdd,
    required this.canSync,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    required this.onSync,
  });

  /// 予定や接続状態が変わったことを知らせる。ダイアログはこれで再描画する。
  final Listenable listenable;
  final List<ScheduleEntry> Function() entries;
  final bool Function() canAdd;
  final bool Function() canSync;
  final Future<void> Function(int hour, int minute, Set<int> weekdays) onAdd;
  final Future<void> Function(String id, bool enabled) onToggle;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function() onSync;
}

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
                  for (final entry in entries) _entryTile(entry),
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

  Widget _entryTile(ScheduleEntry entry) {
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
            onChanged: (on) => _host.onToggle(entry.id, on),
          ),
          IconButton(
            key: Key('schedule-delete-${entry.id}'),
            tooltip: AppStrings.scheduleDeleteTooltip,
            onPressed: () => _host.onDelete(entry.id),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
