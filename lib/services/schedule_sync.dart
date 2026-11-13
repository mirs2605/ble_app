import '../models/schedule_entry.dart';
import 'ble_connection.dart';
import 'schedule_repository.dart';

/// 同期で何をするかの計画。
class ScheduleSyncPlan {
  /// スマホのDBへ保存する行（ロボットの方が新しい／スマホに無い）。
  final List<ScheduleEntry> toStore;

  /// ロボットへ送る行（スマホの方が新しい／ロボットに無い）。
  final List<ScheduleEntry> toPush;

  const ScheduleSyncPlan({required this.toStore, required this.toPush});
}

/// 予定ごとの更新番号（revision）を比べて、採用する側を決める純粋関数。
///
/// - 片方にしか無い行: 無い側へ渡す。
/// - 両方にある行: 更新番号が大きい方を採用する。
/// - 更新番号が同じで内容が違う行（別のスマホが同時に編集した等）:
///   ロボットを正とし、スマホの行を置き換える。
/// 時計の差に左右されないよう、時刻は使わない。
ScheduleSyncPlan planScheduleSync(
  List<ScheduleEntry> local,
  List<ScheduleEntry> remote,
) {
  final localById = {for (final e in local) e.id: e};
  final remoteById = {for (final e in remote) e.id: e};
  final toStore = <ScheduleEntry>[];
  final toPush = <ScheduleEntry>[];

  for (final r in remoteById.values) {
    final l = localById[r.id];
    if (l == null || r.revision > l.revision) {
      toStore.add(r);
    } else if (r.revision == l.revision && r != l) {
      toStore.add(r);
    } else if (l.revision > r.revision) {
      toPush.add(l);
    }
  }
  for (final l in localById.values) {
    if (!remoteById.containsKey(l.id)) toPush.add(l);
  }
  return ScheduleSyncPlan(toStore: toStore, toPush: toPush);
}

class ScheduleSyncResult {
  final bool ok;
  final int stored;
  final int pushed;

  const ScheduleSyncResult({
    required this.ok,
    this.stored = 0,
    this.pushed = 0,
  });
}

/// スマホのDBとロボットのDBを突き合わせる。
///
/// 手順: ロボットの全件を取得 → 計画を立てる → スマホのDBを更新 →
/// ロボットへ新しい行を送る。途中で失敗しても、スマホ側の更新は保たれ、
/// 次回の同期で続きから揃う（同じ計画になる）。
class ScheduleSyncService {
  ScheduleSyncService({required this.repository, required this.connection});

  final ScheduleRepository repository;
  final BleConnection connection;

  Future<ScheduleSyncResult> sync() async {
    final remote = await connection.pullSchedules();
    if (remote == null) return const ScheduleSyncResult(ok: false);

    final plan = planScheduleSync(await repository.all(), remote);
    await repository.saveAll(plan.toStore);

    var pushed = 0;
    for (final entry in plan.toPush) {
      if (!await connection.pushSchedule(entry)) {
        return ScheduleSyncResult(
          ok: false,
          stored: plan.toStore.length,
          pushed: pushed,
        );
      }
      pushed++;
    }
    return ScheduleSyncResult(
      ok: true,
      stored: plan.toStore.length,
      pushed: pushed,
    );
  }
}
