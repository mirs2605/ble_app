import '../models/cleaning_zone.dart';
import '../models/initial_pose.dart';

/// BLE接続の状態
enum BleStatus {
  idle,
  scanning,
  connecting,
  connected,
  sending,
  disconnected,
  error,
}

/// BLE接続の抽象。Controllerはこの型だけに依存し、実体は外から注入する。
/// 単体テストではFakeを差し替え、実機なしでControllerを検証できる。
abstract class BleConnection {
  BleStatus get status;

  /// Bluetooth経由で接続するか。trueならControllerが接続前に権限を要求し、
  /// BLE向けの案内を表示する。
  bool get usesBluetooth;

  void startAutoConnect();

  void stopAutoConnect();

  Future<void> scanAndConnect();

  Future<bool> sendCleaningZone(CleaningZoneMission zone);

  /// 開始地点（2D Pose Estimate）を送信する。
  Future<bool> sendInitialPose(InitialPoseMission pose);

  Future<void> dispose();
}

/// [BleConnection] の生成関数。コールバックをController側から渡すための型。
typedef BleConnectionFactory =
    BleConnection Function({
      required void Function(String message) onLog,
      required void Function(BleStatus status) onStatusChanged,
    });
