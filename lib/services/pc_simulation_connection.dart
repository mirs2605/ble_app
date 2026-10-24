import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/cleaning_zone.dart';
import '../models/initial_pose.dart';
import 'ble_connection.dart';

/// Sends the selected zone to the PC ROS 2 gateway through `adb reverse`.
class PcSimulationConnection implements BleConnection {
  PcSimulationConnection({required this.onLog, required this.onStatusChanged});

  final void Function(String message) onLog;
  final void Function(BleStatus status) onStatusChanged;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);
  BleStatus _status = BleStatus.idle;
  bool _stopped = false;

  @override
  BleStatus get status => _status;

  void _setStatus(BleStatus value) {
    if (_status == value) return;
    _status = value;
    onStatusChanged(value);
  }

  @override
  void startAutoConnect() {
    if (_stopped) return;
    _setStatus(BleStatus.connecting);
  }

  @override
  void stopAutoConnect() {
    _stopped = true;
  }

  @override
  Future<void> scanAndConnect() async {
    if (_stopped) return;
    _setStatus(BleStatus.connecting);
    // The USB reverse tunnel is established by adb on the PC. The receiver
    // is checked on the first send so the app can still open if ROS is starting.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_stopped) return;
    _setStatus(BleStatus.connected);
    onLog('PCシミュレーション: 127.0.0.1:8765 (ADB reverse) への送信準備完了');
  }

  @override
  Future<bool> sendCleaningZone(CleaningZoneMission zone) async {
    if (_stopped || !zone.isValid) return false;
    return _sendPayload('/cleaning_zone', zone.toJson(), '清掃範囲');
  }

  @override
  Future<bool> sendInitialPose(InitialPoseMission pose) async {
    if (_stopped || !pose.isValid) return false;
    return _sendPayload('/initial_pose', pose.toJson(), '開始地点');
  }

  Future<bool> _sendPayload(
    String path,
    Map<String, dynamic> payload,
    String label,
  ) async {
    _setStatus(BleStatus.sending);
    HttpClientResponse? response;
    try {
      final request = await _client
          .postUrl(Uri.parse('http://127.0.0.1:8765$path'))
          .timeout(const Duration(seconds: 6));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      response = await request.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        onLog('PCシミュレーション受信エラー (${response.statusCode}): $body');
        _setStatus(BleStatus.error);
        return false;
      }
      onLog('$labelをPCへ送信しました');
      _setStatus(BleStatus.connected);
      return true;
    } on TimeoutException catch (error) {
      onLog('PCシミュレーション接続がタイムアウトしました。ADB reverse とPCのROS 2を確認してください ($error)');
    } on SocketException catch (error) {
      onLog('PCシミュレーションへ接続できません。ADB reverse とPCのROS 2を確認してください ($error)');
    } catch (error) {
      onLog('PCシミュレーション送信に失敗しました: $error');
    }
    _setStatus(BleStatus.connected);
    return false;
  }

  @override
  Future<void> dispose() async {
    _stopped = true;
    _client.close(force: true);
  }
}
