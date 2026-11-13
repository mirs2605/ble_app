import 'dart:typed_data';

import '../models/ble_status.dart';
import '../models/cleaning_zone.dart';
import '../models/robot_map.dart';
import '../models/schedule_entry.dart';

export '../models/ble_status.dart';

/// BLE接続の抽象。Controllerはこの型だけに依存し、実体は外から注入する。
/// 単体テストではFakeを差し替え、実機なしでControllerを検証できる。
abstract class BleConnection {
  BleStatus get status;

  void startAutoConnect();

  void stopAutoConnect();

  Future<void> scanAndConnect();

  Future<bool> sendCleaningZone(CleaningZoneMission zone);

  /// ロボットが持つ予定を全件（削除済みを含む）取得する。失敗は null。
  Future<List<ScheduleEntry>?> pullSchedules();

  /// 予定1件（削除済みを含む）をロボットへ送る。
  Future<bool> pushSchedule(ScheduleEntry entry);

  /// ロボットが渡せる地図の説明を取得する。失敗は null。
  Future<RobotMapInfo?> pullMapInfo();

  /// [info] の地図データを分割して受け取る。失敗・不一致は null。
  /// [onProgress] には受信済みの bytes と全体の bytes を渡す。
  Future<Uint8List?> pullMapData(
    RobotMapInfo info, {
    void Function(int received, int total)? onProgress,
  });

  Future<void> dispose();
}

/// [BleConnection] の生成関数。コールバックをController側から渡すための型。
typedef BleConnectionFactory = BleConnection Function({
  required void Function(String message) onLog,
  required void Function(BleStatus status) onStatusChanged,
});
