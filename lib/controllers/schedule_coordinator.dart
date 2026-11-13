import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/app_notice.dart';
import '../models/cleaning_zone.dart';
import '../models/schedule_dialog_host.dart';
import '../models/schedule_entry.dart';
import '../services/ble_connection.dart';
import '../services/schedule_repository.dart';
import '../services/schedule_sync.dart';
import '../theme/app_strings.dart';

/// 定時清掃の予定管理と同期の協調役（coordinator）。
///
/// スマホの DB（[ScheduleRepository]）の読み書き、ロボットとの双方向同期
/// （[ScheduleSyncService]）、画面（[ScheduleDialogHost]）への状態提供を
/// 担い、[BleHomeController] から予定の関心事を分離する。
class ScheduleCoordinator extends ChangeNotifier {
  ScheduleCoordinator({
    required ScheduleRepository repository,
    required BleConnection connection,
    required this.selectedPolygon,
    required this.isConnected,
    required this.onLog,
    required this.onNotice,
    ScheduleSyncService? syncService,
  }) : _repo = repository,
       _syncService =
           syncService ??
           ScheduleSyncService(repository: repository, connection: connection) {
    unawaited(loadSchedules());
  }

  final ScheduleRepository _repo;
  final ScheduleSyncService _syncService;
  final ValueGetter<List<MapPoint>> selectedPolygon;
  final ValueGetter<bool> isConnected;
  final ValueChanged<String> onLog;
  final ValueChanged<AppNotice> onNotice;

  List<ScheduleEntry> _schedules = [];
  bool _syncing = false;
  bool _isDisposed = false;

  /// 画面に出す予定（削除済みを除く）。
  List<ScheduleEntry> get schedules => List.unmodifiable(_schedules);

  /// 接続中ならロボットと同期できる。
  bool get canSync => isConnected();

  /// 選択中の範囲で予定を追加できるか（上限32件未満かつ閉じた有効な多角形）。
  bool get canAdd =>
      _schedules.length < ScheduleEntry.maxEntries &&
      CleaningZoneMission(polygon: selectedPolygon()).isValid;

  /// DBから削除済みでない予定を読み込む。
  Future<void> loadSchedules() async {
    if (_isDisposed) return;
    final all = await _repo.all();
    if (_isDisposed) return;
    _schedules = all.where((e) => !e.deleted).toList();
    notifyListeners();
  }

  /// 選択中の範囲を、毎週 [weekdays] の [hour]:[minute] に清掃する予定として
  /// 追加する。スマホの DB へ保存し、接続中ならロボットと同期する。
  Future<void> addSchedule({
    required int hour,
    required int minute,
    required Set<int> weekdays,
  }) async {
    final polygon = selectedPolygon();
    if (polygon.isEmpty) {
      onLog('❌ ${AppStrings.specifyRange}');
      onNotice(AppNotice.specifyRange);
      return;
    }
    final entry = ScheduleEntry.create(
      id: newScheduleId(),
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      polygon: polygon,
    );
    if (!entry.isValid || _schedules.length >= ScheduleEntry.maxEntries) {
      onLog('❌ ${AppStrings.invalidSchedule}');
      onNotice(AppNotice.invalidSchedule);
      return;
    }
    await _repo.save(entry);
    await _afterScheduleChange();
  }

  /// 予定の有効/無効を切り替える。
  Future<void> setScheduleEnabled(String id, bool enabled) =>
      _editSchedule(id, (e) => e.edited(enabled: enabled));

  /// 予定を削除する。行は消さず `deleted: true`（墓標）にして相手側にも伝える。
  Future<void> deleteSchedule(String id) =>
      _editSchedule(id, (e) => e.edited(deleted: true));

  Future<void> _editSchedule(
    String id,
    ScheduleEntry Function(ScheduleEntry) edit,
  ) async {
    final current = await _repo.get(id);
    if (current == null || _isDisposed) return;
    await _repo.save(edit(current));
    await _afterScheduleChange();
  }

  Future<void> _afterScheduleChange() async {
    await loadSchedules();
    if (_isDisposed) return;
    if (isConnected()) {
      await syncSchedules();
    } else {
      onNotice(AppNotice.scheduleSaved);
    }
  }

  /// ロボットと予定を突き合わせる。
  Future<void> syncSchedules({bool announce = true}) async {
    if (_syncing || _isDisposed || !isConnected()) return;
    _syncing = true;
    try {
      final result = await _syncService.sync();
      if (_isDisposed) return;
      await loadSchedules();
      if (_isDisposed) return;
      if (result.ok) {
        onLog(AppStrings.scheduleSyncLog(result.stored, result.pushed));
        if (announce) onNotice(AppNotice.scheduleSynced);
      } else {
        onNotice(AppNotice.scheduleSyncFailed);
      }
    } finally {
      _syncing = false;
    }
  }

  /// BLE接続が確立した直後（connected / sending）に呼ばれ、自動同期を行う。
  void onLinkEstablished() {
    if (_isDisposed) return;
    Future.microtask(() => syncSchedules(announce: false));
  }

  /// 予定画面に渡すための窓口を生成する。
  ScheduleDialogHost createDialogHost({Listenable? extraListenable}) =>
      ScheduleDialogHost(
        listenable: extraListenable == null
            ? this
            : Listenable.merge([this, extraListenable]),
        entries: () => schedules,
        canAdd: () => canAdd,
        canSync: () => canSync,
        onAdd: (h, m, days) => addSchedule(hour: h, minute: m, weekdays: days),
        onToggle: setScheduleEnabled,
        onDelete: deleteSchedule,
        onSync: syncSchedules,
      );

  static final _random = Random.secure();

  /// 端末をまたいで衝突しない予定ID（128bit乱数の16進）。
  static String newScheduleId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
