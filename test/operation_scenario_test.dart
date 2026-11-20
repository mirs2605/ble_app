import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mirs_ble_app/controllers/ble_home_controller.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/services/ble_adapter.dart';
import 'package:mirs_ble_app/services/ble_service.dart';
import 'package:mirs_ble_app/services/map_config_repository.dart';
import 'package:mirs_ble_app/services/schedule_repository.dart';

import 'ble_home_controller_test.dart' show FakePermissions;

/// 現行のロボット側 `ble_server`（mirs2605/ble_server main）を模した BLE アダプタ。
///
/// - 接続中は広告しない（スキャンしても見つからない）。
/// - `cleaning_zone` だけを受け付けて `ACK`、未知の type（予定・地図の受信）は `NACK`。
class SimulatedRobotAdapter implements BleAdapter {
  SimulatedRobotAdapter({this.supportedTypes = const {'cleaning_zone'}});

  final Set<String> supportedTypes;
  bool connected = false;
  final received = <Map<String, dynamic>>[];
  List<int> _response = utf8.encode('NACK');
  final _buffer = <int>[];
  final _linkLoss = StreamController<void>.broadcast();
  int connectCalls = 0;

  @override
  Future<void> ensurePoweredOn() async {}

  @override
  Future<BleFoundDevice?> findTarget({
    required Duration timeout,
    BleAdvertisementCallback? onAdvertisement,
  }) async {
    if (connected) return null;
    return const BleFoundDevice(remoteId: 'robot', name: 'MIRS-Robot');
  }

  @override
  Future<void> connect(String remoteId, {required Duration timeout}) async {
    connectCalls++;
    connected = true;
  }

  @override
  bool get hasReadableResponse => true;

  @override
  Future<BleMtuInfo> negotiateMtu() async => const BleMtuInfo(
    mtu: 247,
    payloadSize: 244,
    requested: true,
    requestFailed: false,
  );

  @override
  Future<int> currentPayloadSize() async => 244;

  @override
  Future<void> writeChunks(List<List<int>> chunks) async {
    for (final chunk in chunks) {
      _buffer.addAll(chunk);
    }
    final end = _buffer.indexOf(10);
    if (end < 0) return;
    final frame = utf8.decode(_buffer.sublist(0, end));
    _buffer.removeRange(0, end + 1);
    final json = jsonDecode(frame) as Map<String, dynamic>;
    received.add(json);
    _response = utf8.encode(
      supportedTypes.contains(json['type']) ? 'ACK' : 'NACK',
    );
  }

  @override
  Future<List<int>> readResponse({required Duration timeout}) async =>
      _response;

  @override
  Stream<void> get linkLoss => _linkLoss.stream;

  void dropLink() {
    connected = false;
    _linkLoss.add(null);
  }

  @override
  Future<void> disconnect() async => connected = false;

  @override
  Future<void> dispose() async => _linkLoss.close();
}

const _zone = [
  MapPoint(x: 1, y: 1),
  MapPoint(x: 4, y: 1),
  MapPoint(x: 4, y: 3),
  MapPoint(x: 1, y: 3),
];

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late ScheduleRepository scheduleRepo;

  setUpAll(() async {
    sqfliteFfiInit();
    await MapConfigRepository.init(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  setUp(() async {
    scheduleRepo = await ScheduleRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      singleInstance: false,
    );
  });

  tearDown(() => scheduleRepo.close());

  BleHomeController build(SimulatedRobotAdapter robot) => BleHomeController(
    connectionFactory: ({required onLog, required onStatusChanged}) =>
        BleService(
          onLog: onLog,
          onStatusChanged: onStatusChanged,
          adapter: robot,
        ),
    permissionGateway: FakePermissions.granted(),
    scheduleRepository: scheduleRepo,
  );

  test('予定同期に未対応のロボットでも、接続を保ったまま清掃範囲を送れる', () async {
    final robot = SimulatedRobotAdapter();
    final controller = build(robot);
    addTearDown(controller.dispose);

    // 接続 → 自動の予定同期（NACK）→ 自動再スキャンの周期（4秒）をまたぐ。
    await _wait(5000);

    expect(robot.received.map((j) => j['type']), contains('schedule_pull'));
    expect(controller.status, BleStatus.connected);
    expect(robot.connectCalls, 1);

    controller.setSelectedMapPoints(_zone);
    expect(controller.canSendSelectedMap, isTrue);
    await controller.sendPressed();

    expect(controller.sendCompleted, isTrue);
    expect(robot.received.last['type'], 'cleaning_zone');
    expect(controller.status, BleStatus.connected);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('清掃範囲が拒否（NACK）されても接続は保たれ、送り直せる', () async {
    final robot = SimulatedRobotAdapter(supportedTypes: const {});
    final controller = build(robot);
    addTearDown(controller.dispose);
    await _wait(100);

    controller.setSelectedMapPoints(_zone);
    await controller.sendPressed();
    expect(controller.sendCompleted, isFalse);

    await _wait(5000);
    expect(controller.status, BleStatus.connected);
    expect(controller.canSendSelectedMap, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('回線が切れたら再接続し、再び送信できる', () async {
    final robot = SimulatedRobotAdapter();
    final controller = build(robot);
    addTearDown(controller.dispose);
    await _wait(100);
    expect(controller.status, BleStatus.connected);

    robot.dropLink();
    await _wait(200);
    expect(controller.status, BleStatus.connected);
    expect(robot.connectCalls, 2);

    controller.setSelectedMapPoints(_zone);
    await controller.sendPressed();
    expect(controller.sendCompleted, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
