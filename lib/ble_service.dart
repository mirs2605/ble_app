// BLE通信のロジックを管理するサービスクラス
import 'dart:convert';
import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// GATT UUID（Pythonサーバー側と一致させること）
class BleUuids {
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String missionCharUuid = '12345678-1234-1234-1234-123456789abd';
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
  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;

  /// 現在の接続状態
  BleStatus status = BleStatus.idle;

  /// ログ出力コールバック
  final void Function(String message) onLog;

  /// 状態変化コールバック
  final void Function(BleStatus status) onStatusChanged;

  BleService({
    required this.onLog,
    required this.onStatusChanged,
  });

  void _setStatus(BleStatus s) {
    status = s;
    onStatusChanged(s);
  }

  void _log(String msg) {
    onLog(msg);
  }

  /// "MIRS-Robot" という名前またはService UUIDを持つデバイスをスキャンして接続する
  Future<void> scanAndConnect() async {
    // アダプタがONになっているか確認
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _log('❌ スマホのBluetoothがOFFです。ONにしてください。');
      _setStatus(BleStatus.error);
      return;
    }

    _setStatus(BleStatus.scanning);
    _log('🔍 スキャン開始...');

    StreamSubscription<List<ScanResult>>? sub;
    bool found = false;

    try {
      // startScan 前にリスナーを登録する
      sub = FlutterBluePlus.onScanResults.listen((results) async {
        for (final r in results) {
          final advName = r.advertisementData.advName;
          final platformName = r.device.platformName;
          final name = advName.isNotEmpty ? advName : platformName;
          final serviceUuids = r.advertisementData.serviceUuids.map((g) => g.str128.toLowerCase()).toList();

          if (name.isNotEmpty) {
            _log('  発見: "$name" (${r.device.remoteId})');
          }

          final targetUuid = BleUuids.serviceUuid.toLowerCase();
          final isMatch = name == 'MIRS-Robot' ||
                          name.contains('MIRS') ||
                          serviceUuids.contains(targetUuid);

          if (!found && isMatch) {
            found = true;
            _log('🎯 ターゲット検出: $name (${r.device.remoteId})');
            await FlutterBluePlus.stopScan();
            await _connect(r.device);
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
      );

      // スキャン終了を待機
      await FlutterBluePlus.isScanning.where((v) => !v).first;

      if (!found && status == BleStatus.scanning) {
        _log('❌ MIRS-Robot が見つかりませんでした (タイムアウト)');
        _setStatus(BleStatus.idle);
      }
    } catch (e) {
      _log('❌ スキャンエラー: $e');
      _setStatus(BleStatus.error);
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    _setStatus(BleStatus.connecting);
    _log('🔗 接続中: ${device.platformName}');

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      _log('✅ 接続成功');

      // サービス・キャラクタリスティクスを取得
      final services = await device.discoverServices();
      for (final svc in services) {
        if (svc.serviceUuid == Guid(BleUuids.serviceUuid)) {
          for (final char in svc.characteristics) {
            if (char.characteristicUuid == Guid(BleUuids.missionCharUuid)) {
              _missionChar = char;
              _log('✅ Mission Characteristic 取得済み');
              break;
            }
          }
        }
      }

      if (_missionChar == null) {
        _log('❌ Mission Characteristic が見つかりません。');
        await device.disconnect();
        _setStatus(BleStatus.error);
        return;
      }

      _setStatus(BleStatus.connected);

      // 切断を監視
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _log('🔌 切断されました');
          _missionChar = null;
          _device = null;
          _setStatus(BleStatus.disconnected);
        }
      });
    } catch (e) {
      _log('❌ 接続エラー: $e');
      _setStatus(BleStatus.error);
    }
  }

  /// 清掃範囲JSONをBLE Writeで送信する（接続は維持）
  Future<bool> sendCleaningZone(Map<String, dynamic> zone) async {
    if (_missionChar == null) {
      _log('❌ 未接続です。先に接続してください。');
      return false;
    }

    _setStatus(BleStatus.sending);
    try {
      final jsonStr = jsonEncode(zone);
      final bytes = utf8.encode(jsonStr);
      _log('📤 送信中 (${bytes.length} bytes)...');
      _log('   $jsonStr');

      // withoutResponse: false = Write With Response（確認あり）
      await _missionChar!.write(bytes, withoutResponse: false);
      _log('✅ 送信完了');
      _setStatus(BleStatus.connected);
      return true;
    } catch (e) {
      _log('❌ 送信エラー: $e');
      _setStatus(BleStatus.error);
      return false;
    }
  }

  /// 切断する
  Future<void> disconnect() async {
    await _device?.disconnect();
    _missionChar = null;
    _device = null;
    _setStatus(BleStatus.idle);
    _log('🔌 切断しました');
  }

  void dispose() {
    _adapterStateSub?.cancel();
    disconnect();
  }
}
