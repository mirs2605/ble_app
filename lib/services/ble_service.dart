// BLE接続の確立と維持だけを担う。送受信の実体は [BleAdapter] に委ね、
// このクラスは状態遷移・ログ・再接続方針に徹する。
// 要求の運搬は [BleRequestChannel]、送る内容ごとの手順は services/protocol/ が受け持つ。
import 'dart:async';

import 'ble_adapter.dart';
import 'ble_connection.dart';
import 'ble_request_channel.dart';
import 'flutter_blue_plus_adapter.dart';

/// 既存の `ble_service.dart` からの参照互換のため再exportする。
export 'ble_connection.dart' show BleStatus;
export 'ble_protocol.dart'
    show BleUuids, BleTargetMatcher, BleConnectionRequirements;
export 'ble_request_channel.dart' show BlePayloadChunker, BleResponse;
export 'ble_robot_link.dart' show BleRobotLink;

class BleReconnectPolicy {
  const BleReconnectPolicy._();

  static bool shouldReconnect({
    required BleStatus status,
    required bool disposed,
  }) {
    return !disposed &&
        status != BleStatus.connected &&
        status != BleStatus.connecting &&
        status != BleStatus.sending;
  }
}

/// BLE接続（スキャン・接続・MTU調整・切断の検知・自動再接続）を管理する。
class BleService implements BleConnection, BleLinkControl {
  static const scanTimeout = Duration(seconds: 8);
  static const connectTimeout = Duration(seconds: 10);
  static const autoScanInterval = Duration(seconds: 4);

  final BleAdapter _adapter;
  StreamSubscription<void>? _linkLossSub;
  Timer? _autoScanTimer;
  bool _isDisposed = false;
  bool _isReady = false;

  /// 現在の接続状態
  @override
  BleStatus status = BleStatus.idle;

  /// ログ出力コールバック
  final void Function(String message) onLog;

  /// 状態変化コールバック
  final void Function(BleStatus status) onStatusChanged;

  BleService({
    required this.onLog,
    required this.onStatusChanged,
    BleAdapter? adapter,
  }) : _adapter = adapter ?? FlutterBluePlusAdapter();

  /// 要求の運搬役が使うアダプタ（同じ接続を共有する）。
  BleAdapter get adapter => _adapter;

  @override
  bool get isReady => _isReady;

  @override
  void startAutoConnect() {
    if (_isDisposed || _autoScanTimer != null) {
      return;
    }

    _autoScanTimer = Timer.periodic(autoScanInterval, (_) async {
      if (_isDisposed ||
          status == BleStatus.connected ||
          status == BleStatus.connecting ||
          status == BleStatus.sending) {
        return;
      }
      await scanAndConnect();
    });
  }

  @override
  void stopAutoConnect() {
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  void _setStatus(BleStatus s) {
    if (_isDisposed) return;
    status = s;
    onStatusChanged(s);
  }

  void _log(String msg) {
    if (_isDisposed) return;
    onLog(msg);
  }

  @override
  Future<void> scanAndConnect() async {
    if (_isDisposed ||
        status == BleStatus.scanning ||
        status == BleStatus.connecting) {
      return;
    }

    try {
      await _adapter.ensurePoweredOn();
    } on BleAdapterException catch (e) {
      if (e.failure == BleAdapterFailure.bluetoothOff) {
        _log('❌ スマホのBluetoothがOFFです。ONにしてください。');
      } else {
        _log('❌ スキャンエラー: ${e.detail}');
      }
      _setStatus(BleStatus.error);
      return;
    }

    _setStatus(BleStatus.scanning);
    _log('🔍 ターゲット BLE をスキャン中...');

    late final BleFoundDevice? found;
    try {
      found = await _adapter.findTarget(
        timeout: scanTimeout,
        onAdvertisement: (name, remoteId) {
          if (name.isNotEmpty) {
            _log('  発見: "$name" ($remoteId)');
          }
        },
      );
    } on BleAdapterException catch (e) {
      _log('❌ スキャンエラー: ${e.detail}');
      _setStatus(BleStatus.error);
      return;
    }
    if (found == null) {
      _log('❌ MIRS-Robot が見つかりませんでした (タイムアウト)');
      _setStatus(BleStatus.idle);
      return;
    }
    _log('🎯 ターゲット検出: ${found.name} (${found.remoteId})');
    await _connect(found);
  }

  Future<void> _connect(BleFoundDevice found) async {
    if (_isDisposed || status == BleStatus.connected) {
      return;
    }

    _setStatus(BleStatus.connecting);
    _log('🔗 接続中: ${found.name}');

    try {
      await _adapter.connect(found.remoteId, timeout: connectTimeout);
    } on BleAdapterException catch (e) {
      if (e.failure == BleAdapterFailure.requirementsUnmet) {
        _log('❌ Mission Characteristic が見つかりません。');
      } else {
        _log('❌ 接続エラー: ${e.detail}');
      }
      _setStatus(BleStatus.error);
      return;
    }
    _log('✅ 接続成功');

    final mtu = await _adapter.negotiateMtu();
    if (mtu.requested) {
      _log('ℹ️ MTUを設定しました: ${mtu.mtu} bytes');
    } else if (mtu.requestFailed) {
      _log('⚠️ MTU設定に失敗したため、現在値を使用します: ${mtu.mtu} bytes');
    } else {
      _log('ℹ️ 現在のMTU: ${mtu.mtu} bytes');
    }

    _isReady = true;
    _setStatus(BleStatus.connected);
    _watchLinkLoss();
  }

  void _watchLinkLoss() {
    _linkLossSub?.cancel();
    _linkLossSub = _adapter.linkLoss.listen((_) => _handleLinkLoss());
  }

  void _handleLinkLoss() {
    if (_isDisposed) return;
    _isReady = false;
    _log('🔌 切断されました');
    _setStatus(BleStatus.disconnected);
    if (BleReconnectPolicy.shouldReconnect(
      status: status,
      disposed: _isDisposed,
    )) {
      Future.microtask(() => scanAndConnect());
    }
  }

  @override
  void beginTransfer() => _setStatus(BleStatus.sending);

  @override
  void endTransfer() {
    if (_isReady) _setStatus(BleStatus.connected);
  }

  /// 書き込み・読み取りの失敗で回線が信用できなくなったとき、接続を切って
  /// error にする。切らずに error にすると、ロボットは接続中のため広告せず、
  /// 自動再スキャンで見つからないまま復帰できない。切断すればロボットが
  /// 広告を再開し、自動接続で張り直せる。
  @override
  Future<void> abandonLink() async {
    _isReady = false;
    try {
      await _adapter.disconnect();
    } catch (_) {}
    _setStatus(BleStatus.error);
  }

  Future<void> disconnect() async {
    await _linkLossSub?.cancel();
    _linkLossSub = null;
    _isReady = false;
    try {
      await _adapter.disconnect();
    } catch (_) {}
    if (!_isDisposed) {
      _setStatus(BleStatus.idle);
    }
    _log('🔌 切断しました');
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    stopAutoConnect();
    await disconnect();
    try {
      await _adapter.dispose();
    } catch (_) {}
  }
}
