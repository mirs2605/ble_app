import 'package:flutter/foundation.dart';

import 'schedule_entry.dart';

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
