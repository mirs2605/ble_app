import 'dart:typed_data';

import '../models/cleaning_zone.dart';
import '../models/robot_map.dart';
import '../models/schedule_entry.dart';
import 'ble_adapter.dart';
import 'ble_connection.dart';
import 'ble_request_channel.dart';
import 'ble_service.dart';
import 'protocol/cleaning_zone_client.dart';
import 'protocol/robot_map_client.dart';
import 'protocol/schedule_client.dart';

/// 本番の [RobotLink]。組み立てと委譲だけを行い、処理は持たない。
///
/// - 接続: [BleService]
/// - 要求の運搬: [BleRequestChannel]
/// - 清掃範囲・予定・地図の手順: [CleaningZoneClient] / [ScheduleClient] / [RobotMapClient]
class BleRobotLink implements RobotLink {
  factory BleRobotLink({
    required void Function(String message) onLog,
    required void Function(BleStatus status) onStatusChanged,
    BleAdapter? adapter,
  }) {
    final connection = BleService(
      onLog: onLog,
      onStatusChanged: onStatusChanged,
      adapter: adapter,
    );
    final channel = BleRequestChannel(
      adapter: connection.adapter,
      link: connection,
      onLog: onLog,
    );
    return BleRobotLink._(
      connection,
      CleaningZoneClient(channel: channel, onLog: onLog),
      ScheduleClient(channel: channel, onLog: onLog),
      RobotMapClient(channel: channel, onLog: onLog),
    );
  }

  BleRobotLink._(this._connection, this._zones, this._schedules, this._maps);

  final BleService _connection;
  final CleaningZoneSender _zones;
  final ScheduleTransport _schedules;
  final RobotMapSource _maps;

  @override
  BleStatus get status => _connection.status;

  @override
  void startAutoConnect() => _connection.startAutoConnect();

  @override
  void stopAutoConnect() => _connection.stopAutoConnect();

  @override
  Future<void> scanAndConnect() => _connection.scanAndConnect();

  @override
  Future<void> dispose() => _connection.dispose();

  @override
  Future<bool> sendCleaningZone(CleaningZoneMission zone) =>
      _zones.sendCleaningZone(zone);

  @override
  Future<List<ScheduleEntry>?> pullSchedules() => _schedules.pullSchedules();

  @override
  Future<bool> pushSchedule(ScheduleEntry entry) =>
      _schedules.pushSchedule(entry);

  @override
  Future<RobotMapInfo?> pullMapInfo() => _maps.pullMapInfo();

  @override
  Future<Uint8List?> pullMapData(
    RobotMapInfo info, {
    void Function(int received, int total)? onProgress,
  }) => _maps.pullMapData(info, onProgress: onProgress);
}
