import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/app_notice.dart';
import 'package:mirs_ble_app/models/cleaning_schedule.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/services/ble_service.dart';
import 'package:mirs_ble_app/services/map_config_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ble_home_controller_test.dart'
    show FakeBleConnection, buildController, flushAsync;
import 'ble_service_test.dart' show FakeBleAdapter;

const _quad = [
  MapPoint(x: 1, y: 1),
  MapPoint(x: 4, y: 1),
  MapPoint(x: 4, y: 3),
  MapPoint(x: 1, y: 3),
];

CleaningScheduleMission _schedule({
  int hour = 9,
  int minute = 30,
  Set<int> weekdays = const {5, 1, 3},
  List<MapPoint> polygon = _quad,
}) => CleaningScheduleMission(
  hour: hour,
  minute: minute,
  weekdays: weekdays,
  zone: CleaningZoneMission(polygon: polygon),
);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await MapConfigRepository.init(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  group('CleaningScheduleMission', () {
    test('JSONは時刻のゼロ埋め・曜日の昇順・閉路のポリゴンを持つ', () {
      final json = _schedule(hour: 6, minute: 5).toJson();

      expect(json['type'], 'cleaning_schedule');
      expect(json['frame_id'], 'map');
      expect(json['time'], '06:05');
      expect(json['weekdays'], [1, 3, 5]);
      final polygon = json['polygon'] as List;
      expect(polygon.length, 5);
      expect(polygon.first, polygon.last);
    });

    test('時刻・曜日・範囲の検証', () {
      expect(_schedule().isValid, isTrue);
      expect(_schedule(hour: 24).isValid, isFalse);
      expect(_schedule(minute: 60).isValid, isFalse);
      expect(_schedule(hour: -1).isValid, isFalse);
      expect(_schedule(weekdays: const {}).isValid, isFalse);
      expect(_schedule(weekdays: const {0}).isValid, isFalse);
      expect(_schedule(weekdays: const {8}).isValid, isFalse);
      expect(_schedule(polygon: const [MapPoint(x: 0, y: 0)]).isValid, isFalse);
    });

    test('解除ミッションはtypeのみ', () {
      expect(const CleaningScheduleCancel().toJson(), {
        'type': 'cleaning_schedule_cancel',
      });
    });
  });

  group('BleService', () {
    test('定時清掃をJSONで送信しACKで成功する', () async {
      final adapter = FakeBleAdapter();
      final service = BleService(
        onLog: (_) {},
        onStatusChanged: (_) {},
        adapter: adapter,
      );
      addTearDown(service.dispose);

      await service.scanAndConnect();
      final sent = await service.sendCleaningSchedule(_schedule());

      expect(sent, isTrue);
      final text = utf8.decode(adapter.written!.expand((c) => c).toList());
      expect(text.endsWith('\n'), isTrue);
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      expect(decoded['type'], 'cleaning_schedule');
      expect(decoded['time'], '09:30');
    });

    test('不正な予定は書き込まない', () async {
      final adapter = FakeBleAdapter();
      final service = BleService(
        onLog: (_) {},
        onStatusChanged: (_) {},
        adapter: adapter,
      );
      addTearDown(service.dispose);

      await service.scanAndConnect();
      final sent = await service.sendCleaningSchedule(
        _schedule(weekdays: const {}),
      );

      expect(sent, isFalse);
      expect(adapter.writeCalls, 0);
    });

    test('解除を送信する', () async {
      final adapter = FakeBleAdapter();
      final service = BleService(
        onLog: (_) {},
        onStatusChanged: (_) {},
        adapter: adapter,
      );
      addTearDown(service.dispose);

      await service.scanAndConnect();
      final sent = await service.cancelCleaningSchedule();

      expect(sent, isTrue);
      final text = utf8.decode(adapter.written!.expand((c) => c).toList());
      expect(jsonDecode(text), {'type': 'cleaning_schedule_cancel'});
    });
  });

  group('BleHomeController', () {
    test('範囲未選択の予約は送信せず通知する', () async {
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
      final controller = buildController(connection: conn);
      addTearDown(controller.dispose);
      await flushAsync();

      await controller.sendSchedule(hour: 9, minute: 0, weekdays: {1});

      expect(conn.schedules, isEmpty);
      expect(controller.activeNotice, AppNotice.specifyRange);
    });

    test('曜日が空の予約は送信せず通知する', () async {
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
      final controller = buildController(connection: conn);
      addTearDown(controller.dispose);
      await flushAsync();
      controller.setSelectedMapPoints(_quad);

      await controller.sendSchedule(hour: 9, minute: 0, weekdays: {});

      expect(conn.schedules, isEmpty);
      expect(controller.activeNotice, AppNotice.invalidSchedule);
    });

    test('予約成功で選択範囲が予定として送られ通知される', () async {
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
      final controller = buildController(connection: conn);
      addTearDown(controller.dispose);
      await flushAsync();
      controller.setSelectedMapPoints(_quad);

      await controller.sendSchedule(hour: 7, minute: 15, weekdays: {2, 4});

      expect(conn.schedules, hasLength(1));
      expect(conn.schedules.single.timeText, '07:15');
      expect(conn.schedules.single.weekdays, {2, 4});
      expect(conn.schedules.single.zone.polygon, _quad);
      expect(controller.activeNotice, AppNotice.scheduleDone);
    });

    test('予約の送信失敗は失敗通知', () async {
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {})
        ..sendResult = false;
      final controller = buildController(connection: conn);
      addTearDown(controller.dispose);
      await flushAsync();
      controller.setSelectedMapPoints(_quad);

      await controller.sendSchedule(hour: 7, minute: 15, weekdays: {2});

      expect(controller.activeNotice, AppNotice.sendFailed);
    });

    test('解除で通知され、範囲の送信済み状態に予約可否は左右されない', () async {
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
      final controller = buildController(connection: conn);
      addTearDown(controller.dispose);
      await flushAsync();
      conn.emit(BleStatus.connected);
      controller.setSelectedMapPoints(_quad);
      expect(controller.canSendSelectedMap, isTrue);
      await controller.sendPressed();
      expect(controller.canSendSelectedMap, isFalse);

      expect(controller.canReserveSchedule, isTrue);
      await controller.cancelSchedule();

      expect(conn.cancelScheduleCalls, 1);
      expect(controller.activeNotice, AppNotice.scheduleCanceled);
    });
  });
}
