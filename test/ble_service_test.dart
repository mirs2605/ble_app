import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/services/ble_adapter.dart';
import 'package:mirs_ble_app/services/ble_service.dart';

const _quad = [
  MapPoint(x: 1, y: 1),
  MapPoint(x: 4, y: 1),
  MapPoint(x: 4, y: 3),
  MapPoint(x: 1, y: 3),
];

class FakeBleAdapter implements BleAdapter {
  bool poweredOn = true;
  BleFoundDevice? findResult = const BleFoundDevice(
    remoteId: 'remote-1',
    name: 'MIRS-Robot',
  );
  BleAdapterException? findError;
  BleAdapterException? connectError;
  BleMtuInfo mtu = const BleMtuInfo(
    mtu: 23,
    payloadSize: 20,
    requested: false,
    requestFailed: false,
  );
  bool payloadSizeFails = false;
  List<List<int>>? written;
  Completer<void>? gateWrite;
  List<int> response = const [65, 67, 75];
  BleAdapterException? readError;

  final linkLossController = StreamController<void>.broadcast();

  int findCalls = 0;
  int connectCalls = 0;
  int writeCalls = 0;
  int readCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> ensurePoweredOn() async {
    if (!poweredOn) {
      throw const BleAdapterException(BleAdapterFailure.bluetoothOff);
    }
  }

  @override
  Future<BleFoundDevice?> findTarget({
    required Duration timeout,
    BleAdvertisementCallback? onAdvertisement,
  }) async {
    findCalls++;
    if (findError != null) throw findError!;
    return findResult;
  }

  @override
  Future<void> connect(String remoteId, {required Duration timeout}) async {
    connectCalls++;
    if (connectError != null) throw connectError!;
  }

  @override
  Future<BleMtuInfo> negotiateMtu() async => mtu;

  @override
  Future<int> currentPayloadSize() async {
    if (payloadSizeFails) {
      throw const BleAdapterException(BleAdapterFailure.mtuUnavailable);
    }
    return mtu.payloadSize;
  }

  @override
  Future<void> writeChunks(List<List<int>> chunks) async {
    writeCalls++;
    if (gateWrite != null) await gateWrite!.future;
    written = chunks;
  }

  @override
  Future<List<int>> readResponse({required Duration timeout}) async {
    readCalls++;
    if (readError != null) throw readError!;
    return response;
  }

  @override
  Stream<void> get linkLoss => linkLossController.stream;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Future<void> dispose() async {
    await linkLossController.close();
  }

  void emitLinkLoss() => linkLossController.add(null);
}

BleService buildService(
  FakeBleAdapter adapter,
  List<String> logs,
  List<BleStatus> statuses,
) {
  return BleService(
    onLog: logs.add,
    onStatusChanged: statuses.add,
    adapter: adapter,
  );
}

Future<void> flushAsync() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('Bluetooth OFFでエラーになる', () async {
    final adapter = FakeBleAdapter()..poweredOn = false;
    final logs = <String>[];
    final statuses = <BleStatus>[];
    final service = buildService(adapter, logs, statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();

    expect(statuses, [BleStatus.error]);
    expect(logs.any((l) => l.contains('BluetoothがOFF')), isTrue);
    expect(adapter.findCalls, 0);
  });

  test('ターゲット不在でタイムアウト扱いとなりidleに戻る', () async {
    final adapter = FakeBleAdapter()..findResult = null;
    final logs = <String>[];
    final statuses = <BleStatus>[];
    final service = buildService(adapter, logs, statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();

    expect(statuses, [BleStatus.scanning, BleStatus.idle]);
    expect(logs.any((l) => l.contains('見つかりませんでした')), isTrue);
  });

  test('スキャン失敗でエラーになる', () async {
    final adapter = FakeBleAdapter()
      ..findError = const BleAdapterException(
        BleAdapterFailure.scanFailed,
        'boom',
      );
    final statuses = <BleStatus>[];
    final service = buildService(adapter, [], statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();

    expect(statuses, [BleStatus.scanning, BleStatus.error]);
  });

  test('接続成功でconnectedになりMTUが記録される', () async {
    final adapter = FakeBleAdapter();
    final logs = <String>[];
    final statuses = <BleStatus>[];
    final service = buildService(adapter, logs, statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();

    expect(statuses, [BleStatus.scanning, BleStatus.connecting, BleStatus.connected]);
    expect(logs.any((l) => l.contains('接続成功')), isTrue);
    expect(logs.any((l) => l.contains('MTU')), isTrue);
  });

  test('要件未充足でエラーになる', () async {
    final adapter = FakeBleAdapter()
      ..connectError = const BleAdapterException(
        BleAdapterFailure.requirementsUnmet,
      );
    final logs = <String>[];
    final statuses = <BleStatus>[];
    final service = buildService(adapter, logs, statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();

    expect(statuses.last, BleStatus.error);
    expect(logs.any((l) => l.contains('Mission Characteristic')), isTrue);
  });

  test('リンク断でdisconnectedになり再スキャンする', () async {
    final adapter = FakeBleAdapter();
    final statuses = <BleStatus>[];
    final service = buildService(adapter, [], statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();
    adapter.emitLinkLoss();
    await flushAsync();

    expect(statuses, [
      BleStatus.scanning,
      BleStatus.connecting,
      BleStatus.connected,
      BleStatus.disconnected,
      BleStatus.scanning,
      BleStatus.connecting,
      BleStatus.connected,
    ]);
    expect(adapter.findCalls, 2);
  });

  test('未接続の送信は拒否される', () async {
    final adapter = FakeBleAdapter();
    final service = buildService(adapter, [], []);
    addTearDown(service.dispose);

    final sent = await service.sendCleaningZone(
      const CleaningZoneMission(polygon: _quad),
    );

    expect(sent, isFalse);
    expect(adapter.writeCalls, 0);
  });

  test('送信成功でconnectedに戻りACKを確認する', () async {
    final adapter = FakeBleAdapter();
    final statuses = <BleStatus>[];
    final service = buildService(adapter, [], statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();
    final sent = await service.sendCleaningZone(
      const CleaningZoneMission(polygon: _quad),
    );

    expect(sent, isTrue);
    expect(statuses.last, BleStatus.connected);
    expect(adapter.writeCalls, 1);
    expect(adapter.readCalls, 1);
    final bytes = adapter.written!.expand((c) => c).toList();
    final decoded = utf8.decode(bytes);
    expect(decoded, contains('cleaning_zone'));
    // チャンク分割がMTUペイロードサイズを守っている。
    expect(adapter.written!.every((c) => c.length <= 20), isTrue);
  });

  test('応答拒否でエラーになる', () async {
    final adapter = FakeBleAdapter()..response = const [78, 65, 67, 75];
    final logs = <String>[];
    final statuses = <BleStatus>[];
    final service = buildService(adapter, logs, statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();
    final sent = await service.sendCleaningZone(
      const CleaningZoneMission(polygon: _quad),
    );

    expect(sent, isFalse);
    expect(statuses.last, BleStatus.error);
    expect(logs.any((l) => l.contains('拒否されました')), isTrue);
  });

  test('応答タイムアウトでエラーになる', () async {
    final adapter = FakeBleAdapter()
      ..readError = const BleAdapterException(
        BleAdapterFailure.responseTimeout,
      );
    final statuses = <BleStatus>[];
    final service = buildService(adapter, [], statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();
    final sent = await service.sendCleaningZone(
      const CleaningZoneMission(polygon: _quad),
    );

    expect(sent, isFalse);
    expect(statuses.last, BleStatus.error);
  });

  test('送信サイズ取得不可でエラーになる', () async {
    final adapter = FakeBleAdapter()..payloadSizeFails = true;
    final statuses = <BleStatus>[];
    final service = buildService(adapter, [], statuses);
    addTearDown(service.dispose);

    await service.scanAndConnect();
    final sent = await service.sendCleaningZone(
      const CleaningZoneMission(polygon: _quad),
    );

    expect(sent, isFalse);
    expect(statuses.last, BleStatus.error);
    expect(adapter.writeCalls, 0);
  });

  test('送信中の二重送信は抑止される', () async {
    final adapter = FakeBleAdapter()..gateWrite = Completer<void>();
    final service = buildService(adapter, [], []);
    addTearDown(() async {
      if (adapter.gateWrite != null && !adapter.gateWrite!.isCompleted) {
        adapter.gateWrite!.complete();
      }
      await service.dispose();
    });

    await service.scanAndConnect();
    final first = service.sendCleaningZone(
      const CleaningZoneMission(polygon: _quad),
    );
    await flushAsync();
    final second = await service.sendCleaningZone(
      const CleaningZoneMission(polygon: _quad),
    );

    expect(second, isFalse);
    adapter.gateWrite!.complete();
    expect(await first, isTrue);
  });

  test('不正ゾーンはAdapterに触れず拒否される', () async {
    final adapter = FakeBleAdapter();
    final service = buildService(adapter, [], []);
    addTearDown(service.dispose);

    await service.scanAndConnect();
    final sent = await service.sendCleaningZone(
      const CleaningZoneMission(
        polygon: [
          MapPoint(x: 0, y: 0),
          MapPoint(x: double.nan, y: 1),
          MapPoint(x: 1, y: 1),
        ],
      ),
    );

    expect(sent, isFalse);
    expect(adapter.writeCalls, 0);
  });
}
