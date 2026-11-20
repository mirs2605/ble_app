import '../../models/schedule_entry.dart';
import '../ble_request_channel.dart';
import 'json_reply.dart';

/// ロボットとの予定のやり取りの窓口。
abstract class ScheduleTransport {
  /// ロボットが持つ予定を全件（削除済みを含む）取得する。失敗は null。
  Future<List<ScheduleEntry>?> pullSchedules();

  /// 予定1件（削除済みを含む）をロボットへ送る。
  Future<bool> pushSchedule(ScheduleEntry entry);
}

/// 予定の取得・反映の手順（`schedule_pull` / `schedule_upsert`）だけを担う。
/// 契約は docs/schedule-contract.md。
class ScheduleClient implements ScheduleTransport {
  ScheduleClient({
    required this._channel,
    required void Function(String message) onLog,
  }) : _log = onLog;

  final BleRequestChannel _channel;
  final void Function(String message) _log;

  @override
  Future<bool> pushSchedule(ScheduleEntry entry) async {
    if (!entry.isValid) {
      _log('❌ 定時清掃の設定が不正です。');
      return false;
    }
    const label = '定時清掃';
    final reply = await _channel.request({
      'type': 'schedule_upsert',
      ...entry.toJson(),
    }, label: label);
    if (reply.status == BleReplyStatus.writtenWithoutResponse) return true;
    if (!reply.received) return false;
    if (!BleResponse.isAccepted(reply.bytes)) {
      _log('❌ ロボット側で$labelが拒否されました: ${describeResponse(reply.bytes)}');
      return false;
    }
    _log('✅ $label送信完了');
    return true;
  }

  /// 予定を1件ずつ取得する。要求（`schedule_pull`）を書き込み、
  /// Response Characteristic に置かれた1件分の JSON を読む。
  @override
  Future<List<ScheduleEntry>?> pullSchedules() async {
    final entries = <ScheduleEntry>[];
    var count = 1;
    for (var index = 0; index < count; index++) {
      final reply = await _channel.request(
        {'type': 'schedule_pull', 'index': index},
        label: '予定の取得',
        quiet: true,
      );
      final page = reply.received ? decodeJsonObject(reply.bytes) : null;
      if (page == null) {
        if (reply.received) {
          _log('❌ ロボット側で予定の取得が拒否されました: ${describeResponse(reply.bytes)}');
        }
        _log('❌ 予定を取得できませんでした。');
        return null;
      }
      final total = page['count'];
      if (total is! int || total < 0) {
        _log('❌ 予定の件数が不正です。');
        return null;
      }
      count = total.clamp(0, ScheduleEntry.maxEntries);
      final item = page['item'];
      if (count == 0 || item is! Map) continue;
      try {
        entries.add(ScheduleEntry.fromJson(Map<String, dynamic>.from(item)));
      } on FormatException catch (e) {
        _log('⚠️ 不正な予定を読み飛ばしました: ${e.message}');
      }
    }
    return entries;
  }
}
