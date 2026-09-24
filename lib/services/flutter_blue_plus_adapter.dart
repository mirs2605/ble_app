import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_adapter.dart';
import 'ble_protocol.dart';

/// [BleAdapter] の実機実装。flutter_blue_plusへの依存はこのファイルに閉じる。
/// `dart:io` は使わず、プラットフォーム分岐は [defaultTargetPlatform] で行う。
class FlutterBluePlusAdapter implements BleAdapter {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _missionChar;
  BluetoothCharacteristic? _responseChar;
  final Map<String, ScanResult> _seen = {};
  final StreamController<void> _linkLossController =
      StreamController<void>.broadcast();
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  bool _disposed = false;

  @override
  Stream<void> get linkLoss => _linkLossController.stream;

  @override
  Future<void> ensurePoweredOn() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 5));
      if (adapterState != BluetoothAdapterState.on) {
        throw const BleAdapterException(BleAdapterFailure.bluetoothOff);
      }
    } on TimeoutException {
      throw const BleAdapterException(BleAdapterFailure.bluetoothOff);
    }
  }

  @override
  Future<BleFoundDevice?> findTarget({
    required Duration timeout,
    BleAdvertisementCallback? onAdvertisement,
  }) async {
    _seen.clear();
    try {
      final matchingResult = FlutterBluePlus.onScanResults
          .expand((results) => results)
          .where((result) {
            final serviceUuids = result.advertisementData.serviceUuids
                .map((uuid) => uuid.str128.toLowerCase())
                .toSet();
            if (!BleTargetMatcher.matchesServiceUuid(serviceUuids)) {
              return false;
            }
            if (_seen.length >= 200) _seen.remove(_seen.keys.first);
            _seen[result.device.remoteId.str] = result;
            onAdvertisement?.call(
              _deviceName(result),
              result.device.remoteId.str,
            );
            return true;
          })
          .first
          .timeout(timeout);

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleUuids.serviceUuid)],
        timeout: timeout,
      );

      final result = await matchingResult;
      return BleFoundDevice(
        remoteId: result.device.remoteId.str,
        name: _deviceName(result),
      );
    } on TimeoutException {
      return null;
    } catch (e) {
      throw BleAdapterException(BleAdapterFailure.scanFailed, e.toString());
    } finally {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    }
  }

  @override
  Future<void> connect(String remoteId, {required Duration timeout}) async {
    if (_disposed) {
      throw const BleAdapterException(
        BleAdapterFailure.connectFailed,
        'disposed',
      );
    }
    final cached = _seen[remoteId];
    if (cached == null) {
      throw BleAdapterException(
        BleAdapterFailure.connectFailed,
        'device not found in scan: $remoteId',
      );
    }
    final device = cached.device;
    try {
      await device.connect(timeout: timeout);
    } catch (e) {
      throw BleAdapterException(BleAdapterFailure.connectFailed, e.toString());
    }
    _device = device;

    try {
      final services = await device.discoverServices();
      final service = services
          .where((svc) => svc.serviceUuid == Guid(BleUuids.serviceUuid))
          .firstOrNull;
      _missionChar = service?.characteristics
          .where(
            (char) =>
                char.characteristicUuid == Guid(BleUuids.missionCharUuid),
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
        await device.disconnect().catchError((_) {});
        _clearEndpoint();
        throw const BleAdapterException(
          BleAdapterFailure.requirementsUnmet,
        );
      }
    } catch (e) {
      if (e is BleAdapterException) rethrow;
      await device.disconnect().catchError((_) {});
      _clearEndpoint();
      throw BleAdapterException(BleAdapterFailure.connectFailed, e.toString());
    }

    await _connectionStateSub?.cancel();
    _connectionStateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _clearEndpoint();
        if (!_disposed && !_linkLossController.isClosed) {
          _linkLossController.add(null);
        }
      }
    });
  }

  @override
  Future<BleMtuInfo> negotiateMtu() async {
    final device = _device;
    if (device == null) {
      throw const BleAdapterException(
        BleAdapterFailure.connectFailed,
        'not connected',
      );
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return BleMtuInfo(
        mtu: device.mtuNow,
        payloadSize: device.mtuNow - 3,
        requested: false,
        requestFailed: false,
      );
    }
    try {
      final mtu = await device.requestMtu(247);
      return BleMtuInfo(
        mtu: mtu,
        payloadSize: mtu - 3,
        requested: true,
        requestFailed: false,
      );
    } catch (_) {
      return BleMtuInfo(
        mtu: device.mtuNow,
        payloadSize: device.mtuNow - 3,
        requested: false,
        requestFailed: true,
      );
    }
  }

  @override
  Future<int> currentPayloadSize() async {
    final device = _device;
    if (device == null) {
      throw const BleAdapterException(
        BleAdapterFailure.mtuUnavailable,
        'not connected',
      );
    }
    final size = device.mtuNow - 3;
    if (size <= 0) {
      throw const BleAdapterException(
        BleAdapterFailure.mtuUnavailable,
        'invalid mtu',
      );
    }
    return size;
  }

  @override
  Future<void> writeChunks(List<List<int>> chunks) async {
    final missionChar = _missionChar;
    if (missionChar == null) {
      throw const BleAdapterException(
        BleAdapterFailure.writeFailed,
        'mission characteristic missing',
      );
    }
    try {
      for (final chunk in chunks) {
        await missionChar
            .write(chunk, withoutResponse: false)
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      throw BleAdapterException(BleAdapterFailure.writeFailed, e.toString());
    }
  }

  @override
  Future<List<int>> readResponse({required Duration timeout}) async {
    final responseChar = _responseChar;
    if (responseChar == null) {
      throw const BleAdapterException(
        BleAdapterFailure.readFailed,
        'response characteristic missing',
      );
    }
    try {
      return await responseChar.read().timeout(timeout);
    } on TimeoutException {
      throw const BleAdapterException(BleAdapterFailure.responseTimeout);
    } catch (e) {
      throw BleAdapterException(BleAdapterFailure.readFailed, e.toString());
    }
  }

  @override
  Future<void> disconnect() async {
    await _connectionStateSub?.cancel();
    _connectionStateSub = null;
    await _device?.disconnect().catchError((_) {});
    _clearEndpoint();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _linkLossController.close().catchError((_) {});
  }

  void _clearEndpoint() {
    _missionChar = null;
    _responseChar = null;
    _device = null;
  }

  String _deviceName(ScanResult result) {
    final advertisedName = result.advertisementData.advName;
    final platformName = result.device.platformName;
    return (advertisedName.isNotEmpty ? advertisedName : platformName).trim();
  }
}
