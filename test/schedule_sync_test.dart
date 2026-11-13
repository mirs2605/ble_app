import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mirs_ble_app/models/app_notice.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/schedule_entry.dart';
import 'package:mirs_ble_app/services/ble_service.dart';
import 'package:mirs_ble_app/services/map_config_repository.dart';
import 'package:mirs_ble_app/services/schedule_repository.dart';
import 'package:mirs_ble_app/services/schedule_sync.dart';

import 'ble_home_controller_test.dart'
    show FakeBleConnection, FakePermissions, flushAsync;
import 'ble_service_test.dart' show FakeBleAdapter;

import 'package:mirs_ble_app/controllers/ble_home_controller.dart';

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
  Set<int> weekdays = const {1, 3, 5},
  bool enabled = true,
  bool deleted = false,
}) => ScheduleEntry(
  id: id,
  revision: revision,
  deleted: deleted,
  enabled: enabled,
  hour: hour,
  minute: minute,
  weekdays: weekdays,
  zone: const CleaningZoneMission(polygon: _quad),
);

Future<ScheduleRepository> _openRepo() => ScheduleRepository.open(
  factory: databaseFactoryFfi,
  path: inMemoryDatabasePath,
  singleInstance: false,
);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await MapConfigRepository.init(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  group('ScheduleEntry', () {
    test('JSONは時刻のゼロ埋め・曜日の昇順・閉路のポリゴンを持つ', () {
      final json = _entry('a', hour: 6, minute: 5).toJson();

      expect(json['id'], 'a');
      expect(json['revision'], 1);
      expect(json['deleted'], false);
      expect(json['enabled'], true);
      expect(json['time'], '06:05');
      expect(json['weekdays'], [1, 3, 5]);
      final polygon = json['polygon'] as List;
      expect(polygon.length, 5);
      expect(polygon.first, polygon.last);
    });

    test('JSONで往復でき、閉路は開路に戻る（比較が揺れない）', () {
      final original = _entry('a', revision: 4);
      final restored = ScheduleEntry.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored, original);
      expect(restored.zone.polygon.length, 4);
    });

    test('SQLiteの行で往復できる', () {
      final original = _entry('a', revision: 2, enabled: false);

      expect(ScheduleEntry.fromMap(original.toMap()), original);
    });

    test('削除済みは時刻などが欠けていても読める', () {
      final entry = ScheduleEntry.fromJson({
        'id': 'gone',
        'revision': 3,
        'deleted': true,
      });

      expect(entry.deleted, isTrue);
      expect(entry.isValid, isTrue);
    });

    test('不正なJSONは FormatException', () {
      expect(() => ScheduleEntry.fromJson({'id': 'a'}), throwsFormatException);
      expect(
        () =>
            ScheduleEntry.fromJson({...(_entry('a').toJson()), 'time': '9:30'}),
        throwsFormatException,
      );
      expect(
        () => ScheduleEntry.fromJson({
          ...(_entry('a').toJson()),
          'weekdays': <int>[],
        }),
        throwsFormatException,
      );
    });

    test('検証: 時刻・曜日・範囲・更新番号', () {
      expect(_entry('a').isValid, isTrue);
      expect(_entry('a', hour: 24).isValid, isFalse);
      expect(_entry('a', minute: 60).isValid, isFalse);
      expect(_entry('a', weekdays: const {}).isValid, isFalse);
      expect(_entry('a', weekdays: const {8}).isValid, isFalse);
      expect(_entry('a', revision: 0).isValid, isFalse);
      expect(_entry('').isValid, isFalse);
    });

    test('edited は内容を保ち更新番号だけ進める', () {
      final edited = _entry('a', revision: 2).edited(enabled: false);

      expect(edited.revision, 3);
      expect(edited.enabled, isFalse);
      expect(edited.hour, 9);
    });
  });

  group('planScheduleSync', () {
    test('片方にしか無い行は無い側へ渡す', () {
      final plan = planScheduleSync([_entry('local')], [_entry('remote')]);

      expect(plan.toStore.map((e) => e.id), ['remote']);
      expect(plan.toPush.map((e) => e.id), ['local']);
    });

    test('更新番号が大きい方を採用する', () {
      final plan = planScheduleSync(
        [_entry('a', revision: 2, hour: 7), _entry('b', revision: 5)],
        [_entry('a', revision: 3, hour: 8), _entry('b', revision: 4)],
      );

      expect(plan.toStore.single.id, 'a');
      expect(plan.toStore.single.hour, 8);
      expect(plan.toPush.single.id, 'b');
    });

    test('更新番号が同じで内容が違えばロボットを正とする', () {
      final plan = planScheduleSync(
        [_entry('a', revision: 2, hour: 7)],
        [_entry('a', revision: 2, hour: 8)],
      );

      expect(plan.toStore.single.hour, 8);
      expect(plan.toPush, isEmpty);
    });

    test('同一なら何もしない', () {
      final plan = planScheduleSync([_entry('a')], [_entry('a')]);

      expect(plan.toStore, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('削除の印は更新番号が新しい側が勝ち、古い行を復活させない', () {
      final plan = planScheduleSync(
        [_entry('a', revision: 1)],
        [_entry('a', revision: 2, deleted: true)],
      );
      expect(plan.toStore.single.deleted, isTrue);
      expect(plan.toPush, isEmpty);

      final reverse = planScheduleSync(
        [_entry('a', revision: 2, deleted: true)],
        [_entry('a', revision: 1)],
      );
      expect(reverse.toPush.single.deleted, isTrue);
      expect(reverse.toStore, isEmpty);
    });
  });

  group('ScheduleRepository', () {
    test('保存・取得・置き換え・墓標の保持', () async {
      final repo = await _openRepo();
      addTearDown(repo.close);

      await repo.saveAll([_entry('b', hour: 10), _entry('a', hour: 8)]);
      expect((await repo.all()).map((e) => e.id), ['a', 'b']);

      await repo.save(_entry('a', revision: 2, deleted: true));
      final a = await repo.get('a');
      expect(a!.deleted, isTrue);
      expect(a.revision, 2);
      expect(await repo.all(), hasLength(2));
      expect(await repo.get('none'), isNull);
    });
  });

  group('ScheduleSyncService', () {
    test('ロボットの新しい行を取り込み、スマホの新しい行を送る', () async {
      final repo = await _openRepo();
      addTearDown(repo.close);
      await repo.saveAll([_entry('mine'), _entry('both', revision: 1)]);
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {})
        ..remoteSchedules = [_entry('robot'), _entry('both', revision: 2)];

      final result = await ScheduleSyncService(
        repository: repo,
        connection: conn,
      ).sync();

      expect(result.ok, isTrue);
      expect(result.stored, 2);
      expect(result.pushed, 1);
      expect(conn.pushed.map((e) => e.id), ['mine']);
      expect((await repo.get('robot')), isNotNull);
      expect((await repo.get('both'))!.revision, 2);
    });

    test('取得に失敗したらDBを変えず失敗を返す', () async {
      final repo = await _openRepo();
      addTearDown(repo.close);
      await repo.save(_entry('mine'));
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {})
        ..remoteSchedules = null;

      final result = await ScheduleSyncService(
        repository: repo,
        connection: conn,
      ).sync();

      expect(result.ok, isFalse);
      expect(conn.pushed, isEmpty);
      expect(await repo.all(), hasLength(1));
    });

    test('送信に失敗しても取り込み済みの分は残り、次回は続きから揃う', () async {
      final repo = await _openRepo();
      addTearDown(repo.close);
      await repo.save(_entry('mine'));
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {})
        ..remoteSchedules = [_entry('robot')]
        ..pushResult = false;
      final service = ScheduleSyncService(repository: repo, connection: conn);

      expect((await service.sync()).ok, isFalse);
      expect(await repo.get('robot'), isNotNull);

      conn.pushResult = true;
      conn.remoteSchedules = [_entry('robot')];
      final retry = await service.sync();
      expect(retry.ok, isTrue);
      expect(retry.stored, 0);
      expect(retry.pushed, 1);
    });
  });

  group('BleService', () {
    BleService build(FakeBleAdapter adapter, List<String> logs) =>
        BleService(onLog: logs.add, onStatusChanged: (_) {}, adapter: adapter);

    List<int> reply(Map<String, dynamic> json) => utf8.encode(jsonEncode(json));

    test('予定を1件ずつ取得して全件を返す', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);
      adapter.responseQueue.addAll([
        reply({'count': 2, 'index': 0, 'item': _entry('a').toJson()}),
        reply({
          'count': 2,
          'index': 1,
          'item': {'id': 'b', 'revision': 3, 'deleted': true},
        }),
      ]);

      await service.scanAndConnect();
      final entries = await service.pullSchedules();

      expect(entries!.map((e) => e.id), ['a', 'b']);
      expect(entries.last.deleted, isTrue);
      expect(adapter.readCalls, 2);
      final request = jsonDecode(
        utf8.decode(adapter.written!.expand((c) => c).toList()),
      );
      expect(request, {'type': 'schedule_pull', 'index': 1});
    });

    test('件数0なら空リスト', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);
      adapter.responseQueue.add(reply({'count': 0, 'index': 0}));

      await service.scanAndConnect();

      expect(await service.pullSchedules(), isEmpty);
    });

    test('応答がJSONでなければ取得失敗（null）', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);
      adapter.responseQueue.add(utf8.encode('NACK'));

      await service.scanAndConnect();

      expect(await service.pullSchedules(), isNull);
    });

    test('不正な1件は読み飛ばし、残りは返す', () async {
      final adapter = FakeBleAdapter();
      final logs = <String>[];
      final service = build(adapter, logs);
      addTearDown(service.dispose);
      adapter.responseQueue.addAll([
        reply({
          'count': 2,
          'index': 0,
          'item': {'id': 'x'},
        }),
        reply({'count': 2, 'index': 1, 'item': _entry('ok').toJson()}),
      ]);

      await service.scanAndConnect();
      final entries = await service.pullSchedules();

      expect(entries!.map((e) => e.id), ['ok']);
      expect(logs.any((l) => l.contains('読み飛ばしました')), isTrue);
    });

    test('応答特性が読めないサーバーでは取得できない', () async {
      final adapter = FakeBleAdapter()..hasReadableResponse = false;
      final service = build(adapter, []);
      addTearDown(service.dispose);

      await service.scanAndConnect();

      expect(await service.pullSchedules(), isNull);
    });

    test('予定の送信は schedule_upsert でACKを確認する', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);

      await service.scanAndConnect();
      final sent = await service.pushSchedule(_entry('a', revision: 3));

      expect(sent, isTrue);
      final body = jsonDecode(
        utf8.decode(adapter.written!.expand((c) => c).toList()),
      ) as Map<String, dynamic>;
      expect(body['type'], 'schedule_upsert');
      expect(body['id'], 'a');
      expect(body['revision'], 3);
    });

    test('墓標も送れ、不正な予定は書き込まない', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);

      await service.scanAndConnect();
      expect(await service.pushSchedule(_entry('a', deleted: true)), isTrue);
      final writes = adapter.writeCalls;
      expect(await service.pushSchedule(_entry('a', hour: 99)), isFalse);
      expect(adapter.writeCalls, writes);
    });
  });

  group('BleHomeController', () {
    Future<(BleHomeController, FakeBleConnection, ScheduleRepository)> setUp({
      List<ScheduleEntry> remote = const [],
    }) async {
      final repo = await _openRepo();
      final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {})
        ..remoteSchedules = remote;
      final controller = BleHomeController(
        connectionFactory: ({required onLog, required onStatusChanged}) {
          conn.onLog = onLog;
          conn.onStatusChanged = onStatusChanged;
          return conn;
        },
        permissionGateway: FakePermissions.granted(),
        scheduleRepository: repo,
      );
      addTearDown(() async {
        controller.dispose();
        await repo.close();
      });
      await flushAsync();
      return (controller, conn, repo);
    }

    test('範囲未選択の追加は保存せず通知する', () async {
      final (controller, _, repo) = await setUp();

      await controller.addSchedule(hour: 9, minute: 0, weekdays: {1});

      expect(await repo.all(), isEmpty);
      expect(controller.activeNotice, AppNotice.specifyRange);
    });

    test('曜日が空の追加は保存せず通知する', () async {
      final (controller, _, repo) = await setUp();
      controller.setSelectedMapPoints(_quad);

      await controller.addSchedule(hour: 9, minute: 0, weekdays: {});

      expect(await repo.all(), isEmpty);
      expect(controller.activeNotice, AppNotice.invalidSchedule);
    });

    test('未接続で追加するとスマホに保存だけして未同期を知らせる', () async {
      final (controller, conn, repo) = await setUp();
      controller.setSelectedMapPoints(_quad);

      await controller.addSchedule(hour: 7, minute: 15, weekdays: {2, 4});

      expect(controller.schedules.single.timeText, '07:15');
      expect((await repo.all()).single.revision, 1);
      expect(conn.pushed, isEmpty);
      expect(controller.activeNotice, AppNotice.scheduleSaved);
    });

    test('接続中に追加するとロボットへ送って同期済みを知らせる', () async {
      final (controller, conn, _) = await setUp();
      conn.emit(BleStatus.connected);
      await flushAsync();
      controller.setSelectedMapPoints(_quad);

      await controller.addSchedule(hour: 7, minute: 15, weekdays: {2, 4});

      expect(conn.pushed.single.timeText, '07:15');
      expect(controller.activeNotice, AppNotice.scheduleSynced);
    });

    test('接続が確立すると自動で同期し、ロボットの予定が一覧に出る', () async {
      final (controller, conn, _) = await setUp(
        remote: [_entry('robot', hour: 6)],
      );

      conn.emit(BleStatus.connected);
      await flushAsync();

      expect(controller.schedules.map((e) => e.id), ['robot']);
    });

    test('削除は墓標になり一覧から消え、ロボットへ伝わる', () async {
      final (controller, conn, repo) = await setUp();
      conn.emit(BleStatus.connected);
      await flushAsync();
      controller.setSelectedMapPoints(_quad);
      await controller.addSchedule(hour: 7, minute: 0, weekdays: {1});
      final id = controller.schedules.single.id;

      await controller.deleteSchedule(id);

      expect(controller.schedules, isEmpty);
      final row = await repo.get(id);
      expect(row!.deleted, isTrue);
      expect(row.revision, 2);
      expect(conn.pushed.last.deleted, isTrue);
    });

    test('有効/無効の切替は更新番号を進める', () async {
      final (controller, _, repo) = await setUp();
      controller.setSelectedMapPoints(_quad);
      await controller.addSchedule(hour: 7, minute: 0, weekdays: {1});
      final id = controller.schedules.single.id;

      await controller.setScheduleEnabled(id, false);

      expect(controller.schedules.single.enabled, isFalse);
      expect((await repo.get(id))!.revision, 2);
    });

    test('同期に失敗しても予定は保存済みで失敗を知らせる', () async {
      final (controller, conn, repo) = await setUp();
      conn.emit(BleStatus.connected);
      await flushAsync();
      conn.remoteSchedules = null;
      controller.setSelectedMapPoints(_quad);

      await controller.addSchedule(hour: 7, minute: 0, weekdays: {1});

      expect(await repo.all(), hasLength(1));
      expect(controller.activeNotice, AppNotice.scheduleSyncFailed);
    });
  });
}
