// BLE通信のオーケストレーション。送受信の実体は [BleAdapter] に委ね、
// このクラスは状態遷移・ログ・再試行方針に徹する。
import 'dart:async';
import 'dart:convert';

import '../models/cleaning_zone.dart';
import 'ble_adapter.dart';
import 'ble_connection.dart';
import 'flutter_blue_plus_adapter.dart';

/// BLE接続の状態は [BleConnection] 側に定義（循環import回避）。
/// 既存の `ble_service.dart` からの参照互換のため再exportする。
export 'ble_connection.dart' show BleStatus;
export 'ble_protocol.dart'
    show BleUuids, BleTargetMatcher, BleConnectionRequirements;

class BlePayloadChunker {
  const BlePayloadChunker._();

  static List<List<int>> split(List<int> payload, int chunkSize) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize');
    }
    return [
      for (var offset = 0; offset < payload.length; offset += chunkSize)
        payload.sublist(offset, (offset + chunkSize).clamp(0, payload.length)),
    ];
  }
}

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

class BleResponse {
  const BleResponse._();

  static bool isAccepted(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false) == 'ACK';
    } on FormatException {
      return false;
    }
  }
}

/// BLE通信を管理するサービス
class BleService implements BleConnection {
  static const scanTimeout = Duration(seconds: 8);
  static const connectTimeout = Duration(seconds: 10);
  static const responseTimeout = Duration(seconds: 5);
  static const maxPayloadBytes = 4096;

  final BleAdapter _adapter;
  StreamSubscription<void>? _linkLossSub;
  Timer? _autoScanTimer;
  bool _isDisposed = false;
  bool _isSending = false;
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

  @override
  void startAutoConnect() {
    if (_isDisposed || _autoScanTimer != null) {
      return;
    }

    _autoScanTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
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
  Future<bool> sendCleaningZone(CleaningZoneMission zone) async {
    if (!_isReady) {
      _log('❌ 未接続です。先に接続してください。');
      return false;
    }
    if (_isSending) {
      _log('⚠️ 送信中です。完了するまで次のミッションは送信できません。');
      return false;
    }
    if (!zone.isValid) {
      _log('❌ 清掃範囲が不正です。');
      return false;
    }

    _isSending = true;
    _setStatus(BleStatus.sending);
    try {
      final jsonStr = jsonEncode(zone.toJson());
      final bytes = utf8.encode('$jsonStr\n');
      late final int payloadSize;
      try {
        payloadSize = await _adapter.currentPayloadSize();
      } on BleAdapterException {
        _log('❌ BLEの送信可能サイズを取得できません。');
        _setStatus(BleStatus.error);
        return false;
      }
      if (bytes.length > maxPayloadBytes) {
        _log('❌ 清掃範囲データが大きすぎます (${bytes.length} bytes)。');
        _setStatus(BleStatus.connected);
        return false;
      }
      _log('📤 送信中 (${bytes.length} bytes)...');
      _log('   $jsonStr');

      try {
        await _adapter.writeChunks(
          BlePayloadChunker.split(bytes, payloadSize),
        );
      } on BleAdapterException catch (e) {
        _log('❌ 送信エラー: ${e.detail}');
        _isReady = false;
        _setStatus(BleStatus.error);
        return false;
      }
      late final List<int> response;
      try {
        response = await _adapter.readResponse(timeout: responseTimeout);
      } on BleAdapterException catch (e) {
        _log('❌ 送信エラー: ${e.detail}');
        _isReady = false;
        _setStatus(BleStatus.error);
        return false;
      }
      if (!BleResponse.isAccepted(response)) {
        final responseText = utf8.decode(response, allowMalformed: true);
        _log('❌ ロボット側でミッションが拒否されました: $responseText');
        _setStatus(BleStatus.error);
        return false;
      }
      _log('✅ 送信完了');
      _setStatus(BleStatus.connected);
      return true;
    } catch (e) {
      _log('❌ 送信エラー: $e');
      _setStatus(BleStatus.error);
      return false;
    } finally {
      _isSending = false;
    }
  }

  Future<void> disconnect() async {
    await _linkLossSub?.cancel();
    _linkLossSub = null;
    _isReady = false;
    _isSending = false;
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
