import '../../models/cleaning_zone.dart';
import '../ble_request_channel.dart';
import 'json_reply.dart';

/// 清掃範囲をロボットへ送る窓口。
abstract class CleaningZoneSender {
  Future<bool> sendCleaningZone(CleaningZoneMission zone);
}

/// 清掃範囲の送信手順（`cleaning_zone` → `ACK` / `NACK`）だけを担う。
class CleaningZoneClient implements CleaningZoneSender {
  CleaningZoneClient({
    required this._channel,
    required void Function(String message) onLog,
  }) : _log = onLog;

  final BleRequestChannel _channel;
  final void Function(String message) _log;

  static const _label = '清掃範囲';

  @override
  Future<bool> sendCleaningZone(CleaningZoneMission zone) async {
    if (!zone.isValid) {
      _log('❌ 清掃範囲が不正です。');
      return false;
    }
    final reply = await _channel.request(zone.toJson(), label: _label);
    switch (reply.status) {
      case BleReplyStatus.writtenWithoutResponse:
        return true;
      case BleReplyStatus.received:
        if (BleResponse.isAccepted(reply.bytes)) {
          _log('✅ $_label送信完了');
          return true;
        }
        _log('❌ ロボット側で$_labelが拒否されました: ${describeResponse(reply.bytes)}');
        return false;
      case BleReplyStatus.notReady:
      case BleReplyStatus.busy:
      case BleReplyStatus.tooLarge:
      case BleReplyStatus.linkFailed:
        return false;
    }
  }
}
