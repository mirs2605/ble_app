// BLE通信のロジックを管理するサービスクラス
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/cleaning_zone.dart';

/// GATT UUID（Pythonサーバー側と一致させること）
class BleUuids {
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String missionCharUuid = '12345678-1234-1234-1234-123456789abd';
  static const String responseCharUuid = '12345678-1234-1234-1234-123456789abe';
}

class BleTargetMatcher {
  const BleTargetMatcher._();

  static bool matchesServiceUuid(Iterable<String> advertisedUuids) {
    return advertisedUuids.any(
      (uuid) => uuid.toLowerCase() == BleUuids.serviceUuid.toLowerCase(),
    );
  }
}

class BleConnectionRequirements {
  const BleConnectionRequirements._();

  static bool hasWritableMissionAndReadableResponse({
    required bool missionFound,
    required bool missionWritable,
    required bool responseFound,
    required bool responseReadable,
  }) {
    return missionFound && missionWritable && responseFound && responseReadable;
  }
}

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

/// BLE通信を管理するサービス
class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _missionChar;
  BluetoothCharacteristic? _responseChar;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  Timer? _autoScanTimer;
  bool _isDisposed = false;
  bool _isSending = false;

  /// 現在の接続状態
  BleStatus status = BleStatus.idle;

  /// ログ出力コールバック
  final void Function(String message) onLog;

  /// 状態変化コールバック
  final void Function(BleStatus status) onStatusChanged;

  BleService({required this.onLog, required this.onStatusChanged});

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

  Future<void> scanAndConnect() async {
    if (_isDisposed ||
        status == BleStatus.scanning ||
        status == BleStatus.connecting) {
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _log('❌ スマホのBluetoothがOFFです。ONにしてください。');
      _setStatus(BleStatus.error);
      return;
    }

    _setStatus(BleStatus.scanning);
    _log('🔍 ターゲット BLE をスキャン中...');

    try {
      final matchingResult = FlutterBluePlus.onScanResults
          .expand((results) => results)
          .where(_isTarget)
          .first
          .timeout(const Duration(seconds: 8));

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleUuids.serviceUuid)],
        timeout: const Duration(seconds: 8),
      );

      final result = await matchingResult;
      final name = _deviceName(result);
      _log('🎯 ターゲット検出: $name (${result.device.remoteId})');
      await FlutterBluePlus.stopScan();
      await _connect(result.device);
    } on TimeoutException {
      _log('❌ MIRS-Robot が見つかりませんでした (タイムアウト)');
      _setStatus(BleStatus.idle);
    } catch (e) {
      _log('❌ スキャンエラー: $e');
      _setStatus(BleStatus.error);
    } finally {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    }
  }

  bool _isTarget(ScanResult result) {
    final name = _deviceName(result);
    final serviceUuids = result.advertisementData.serviceUuids
        .map((uuid) => uuid.str128.toLowerCase())
        .toSet();

    final isUuidMatch = BleTargetMatcher.matchesServiceUuid(serviceUuids);

    if (name.isNotEmpty) {
      _log('  発見: "$name" (${result.device.remoteId})');
    }

    return isUuidMatch;
  }

  String _deviceName(ScanResult result) {
    final advertisedName = result.advertisementData.advName;
    final platformName = result.device.platformName;
    return (advertisedName.isNotEmpty ? advertisedName : platformName).trim();
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_isDisposed || status == BleStatus.connected) {
      return;
    }

    _setStatus(BleStatus.connecting);
    _log('🔗 接続中: ${device.platformName}');

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      _log('✅ 接続成功');

      final services = await device.discoverServices();
      final service = services
          .where((svc) => svc.serviceUuid == Guid(BleUuids.serviceUuid))
          .firstOrNull;
      _missionChar = service?.characteristics
          .where(
            (char) => char.characteristicUuid == Guid(BleUuids.missionCharUuid),
          )
          .firstOrNull;
      _responseChar = service?.characteristics
          .where(
            (char) =>
                char.characteristicUuid == Guid(BleUuids.responseCharUuid),
          )
          .firstOrNull;

      if (!BleConnectionRequirements.hasWritableMissionAndReadableResponse(
        missionFound: _missionChar != null,
        missionWritable: _missionChar?.properties.write ?? false,
        responseFound: _responseChar != null,
        responseReadable: _responseChar?.properties.read ?? false,
      )) {
        _log('❌ Mission Characteristic が見つかりません。');
        await device.disconnect();
        _missionChar = null;
        _responseChar = null;
        _device = null;
        _setStatus(BleStatus.error);
        return;
      }
      await _requestMtu(device);

      _setStatus(BleStatus.connected);

      await _connectionStateSub?.cancel();
      _connectionStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _log('🔌 切断されました');
          _missionChar = null;
          _device = null;
          _setStatus(BleStatus.disconnected);
          if (BleReconnectPolicy.shouldReconnect(
            status: status,
            disposed: _isDisposed,
          )) {
            Future.microtask(() => scanAndConnect());
          }
        }
      });
    } catch (e) {
      _log('❌ 接続エラー: $e');
      _setStatus(BleStatus.error);
    }
  }

  Future<bool> sendCleaningZone(CleaningZoneMission zone) async {
    if (_missionChar == null) {
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
      final mtuPayloadSize = _missionChar!.device.mtuNow - 3;
      if (mtuPayloadSize <= 0) {
        _log('❌ BLEの送信可能サイズを取得できません。');
        _setStatus(BleStatus.error);
        return false;
      }
      if (bytes.length > 4096) {
        _log('❌ 清掃範囲データが大きすぎます (${bytes.length} bytes)。');
        _setStatus(BleStatus.connected);
        return false;
      }
      _log('📤 送信中 (${bytes.length} bytes)...');
      _log('   $jsonStr');

      for (final chunk in BlePayloadChunker.split(bytes, mtuPayloadSize)) {
        await _missionChar!.write(chunk, withoutResponse: false);
      }
      final response = await _responseChar!.read().timeout(
        const Duration(seconds: 5),
      );
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

  Future<void> _requestMtu(BluetoothDevice device) async {
    if (!Platform.isAndroid) {
      _log('ℹ️ 現在のMTU: ${device.mtuNow} bytes');
      return;
    }

    try {
      final mtu = await device.requestMtu(247);
      _log('ℹ️ MTUを設定しました: $mtu bytes');
    } catch (e) {
      _log('⚠️ MTU設定に失敗したため、現在値を使用します: ${device.mtuNow} bytes');
    }
  }

  Future<void> disconnect() async {
    await _connectionStateSub?.cancel();
    _connectionStateSub = null;
    await _device?.disconnect();
    _missionChar = null;
    _responseChar = null;
    _device = null;
    _isSending = false;
    if (!_isDisposed) {
      _setStatus(BleStatus.idle);
    }
    _log('🔌 切断しました');
  }

  Future<void> dispose() async {
    _isDisposed = true;
    stopAutoConnect();
    await disconnect();
  }
}
