import '../models/ble_status.dart';
import 'protocol/cleaning_zone_client.dart';
import 'protocol/robot_map_client.dart';
import 'protocol/schedule_client.dart';

export '../models/ble_status.dart';
export 'protocol/cleaning_zone_client.dart' show CleaningZoneSender;
export 'protocol/robot_map_client.dart' show RobotMapSource;
export 'protocol/schedule_client.dart' show ScheduleTransport;

/// BLE接続の抽象。接続の確立・維持と状態の公開だけを約束する。
/// 送る内容ごとの手順は [CleaningZoneSender] / [ScheduleTransport] /
/// [RobotMapSource] が受け持つ。
abstract class BleConnection {
  BleStatus get status;

  void startAutoConnect();

  void stopAutoConnect();

  Future<void> scanAndConnect();

  Future<void> dispose();
}

/// ロボットとのつながり一式（接続 + 各手順の窓口）。Controller が受け取り、
/// 各協調役には必要な窓口だけを渡す。単体テストでは Fake を差し替える。
abstract class RobotLink
    implements
        BleConnection,
        CleaningZoneSender,
        ScheduleTransport,
        RobotMapSource {}

/// [RobotLink] の生成関数。コールバックをController側から渡すための型。
typedef BleConnectionFactory = RobotLink Function({
  required void Function(String message) onLog,
  required void Function(BleStatus status) onStatusChanged,
});
