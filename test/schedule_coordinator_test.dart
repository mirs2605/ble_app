import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mirs_ble_app/controllers/schedule_coordinator.dart';
import 'package:mirs_ble_app/models/app_notice.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/schedule_entry.dart';
import 'package:mirs_ble_app/services/schedule_repository.dart';

import 'ble_home_controller_test.dart' show FakeBleConnection, flushAsync;

const _quad = [
  MapPoint(x: 1, y: 1),
  MapPoint(x: 4, y: 1),
  MapPoint(x: 4, y: 3),
  MapPoint(x: 1, y: 3),
];

ScheduleEntry _entry(
  String id, {
  int revision = 1,
  int hour = 9,
  int minute = 30,
}) => ScheduleEntry(
  id: id,
  revision: revision,
  hour: hour,
  minute: minute,
  weekdays: const {1, 3, 5},
  zone: const CleaningZoneMission(polygon: _quad),
);

Future<ScheduleRepository> _openRepo() => ScheduleRepository.open(
  factory: databaseFactoryFfi,
  path: inMemoryDatabasePath,
  singleInstance: false,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ScheduleCoordinator', () {
    test('DBから初期読み込みし、createDialogHost経由で操作できる', () async {
      final repo = await _openRepo();
      addTearDown(repo.close);
      await repo.save(_entry('saved', hour: 8));

      final logs = <String>[];
      final notices = <AppNotice>[];
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});

      final coordinator = ScheduleCoordinator(
        repository: repo,
        connection: conn,
        selectedPolygon: () => _quad,
        isConnected: () => true,
        onLog: logs.add,
        onNotice: notices.add,
      );
      addTearDown(coordinator.dispose);

      await flushAsync();

      expect(coordinator.schedules.length, 1);
      expect(coordinator.schedules.first.id, 'saved');

      final host = coordinator.createDialogHost();
      expect(host.canAdd(), isTrue);
      expect(host.canSync(), isTrue);
      expect(host.entries().map((e) => e.id), ['saved']);

      // トグル
      await host.onToggle('saved', false);
      expect(coordinator.schedules.first.enabled, isFalse);

      // 削除（墓標化）
      await host.onDelete('saved');
      expect(coordinator.schedules, isEmpty);
      final stored = await repo.get('saved');
      expect(stored!.deleted, isTrue);

      // 追加
      await host.onAdd(10, 15, {1, 2});
      expect(coordinator.schedules.length, 1);
      expect(coordinator.schedules.first.timeText, '10:15');
      expect(notices, contains(AppNotice.scheduleSynced));
    });

    test('接続確立時に自動同期がトリガーされる', () async {
      final repo = await _openRepo();
      addTearDown(repo.close);

      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {})
        ..remoteSchedules = [_entry('remote', hour: 12)];

      var connected = false;
      final coordinator = ScheduleCoordinator(
        repository: repo,
        connection: conn,
        selectedPolygon: () => _quad,
        isConnected: () => connected,
        onLog: (_) {},
        onNotice: (_) {},
      );
      addTearDown(coordinator.dispose);
      await flushAsync();

      expect(coordinator.schedules, isEmpty);

      connected = true;
      coordinator.onLinkEstablished();
      await flushAsync();

      expect(coordinator.schedules.map((e) => e.id), ['remote']);
    });
  });
}
