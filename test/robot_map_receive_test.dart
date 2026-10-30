import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/controllers/robot_map_receiver.dart';
import 'package:mirs_ble_app/models/map_config.dart';
import 'package:mirs_ble_app/models/robot_map.dart';
import 'package:mirs_ble_app/services/ble_service.dart';
import 'package:mirs_ble_app/services/pgm_codec.dart';
import 'package:mirs_ble_app/widgets/map_management_button.dart';

import 'ble_home_controller_test.dart' show FakeBleConnection;
import 'ble_service_test.dart' show FakeBleAdapter;

Map<String, dynamic> _infoJson({
  String format = 'png',
  int size = 100,
  int width = 4,
  int height = 2,
}) => {
  'name': 'slam',
  'format': format,
  'size': size,
  'width': width,
  'height': height,
  'resolution': 0.05,
  'origin_x': -10.0,
  'origin_y': -5.5,
};

/// 幅 [w] 高さ [h] の P5 (バイナリ) PGM。
Uint8List _pgm(int w, int h, {int fill = 254}) => Uint8List.fromList([
  ...ascii.encode('P5\n# slam\n$w $h\n255\n'),
  ...List.filled(w * h, fill),
]);

void main() {
  group('RobotMapInfo', () {
    test('正しいJSONを読める（nameが無ければ既定名）', () {
      final json = _infoJson()..remove('name');
      final info = RobotMapInfo.fromJson(json);

      expect(info.name, 'ロボットの地図');
      expect(info.width, 4);
      expect(info.resolution, 0.05);
      expect(info.originX, -10.0);
      expect(info.isPgm, isFalse);
      expect(info.crc32, isNull);
    });

    test('不正な項目は FormatException', () {
      for (final bad in [
        _infoJson(format: 'jpg'),
        _infoJson(size: 0),
        _infoJson(size: RobotMapInfo.maxBytes + 1),
        _infoJson(width: 0),
        _infoJson(height: RobotMapInfo.maxSide + 1),
        {..._infoJson(), 'resolution': 0},
        {..._infoJson(), 'origin_x': 'x'},
        {..._infoJson(), 'crc32': -1},
      ]) {
        expect(() => RobotMapInfo.fromJson(bad), throwsFormatException);
      }
    });

    test('crc32 は標準の値と一致する', () {
      expect(crc32(ascii.encode('123456789')), 0xCBF43926);
      expect(crc32(const []), 0);
    });
  });

  group('pgmToPng', () {
    testWidgets('P5をPNGにして寸法を保つ', (tester) async {
      await tester.runAsync(() async {
        final png = await pgmToPng(_pgm(3, 2, fill: 0));

        expect(pngDimensions(png), (3, 2));
      });
    });

    testWidgets('P2（テキスト）も読める', (tester) async {
      await tester.runAsync(() async {
        final png = await pgmToPng(
          Uint8List.fromList(ascii.encode('P2\n2 2\n255\n0 100\n200 254\n')),
        );

        expect(pngDimensions(png), (2, 2));
      });
    });

    test('PGMでない・画素が足りない・最大値が未対応は FormatException', () async {
      await expectLater(
        pgmToPng(Uint8List.fromList(ascii.encode('P6\n1 1\n255\n'))),
        throwsFormatException,
      );
      await expectLater(
        pgmToPng(Uint8List.fromList(ascii.encode('P5\n4 4\n255\nab'))),
        throwsFormatException,
      );
      await expectLater(
        pgmToPng(Uint8List.fromList(ascii.encode('P5\n1 1\n65535\n\x00\x00'))),
        throwsFormatException,
      );
    });

    test('PNGでないデータの寸法は null', () {
      expect(pngDimensions(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('BleService', () {
    BleService build(FakeBleAdapter adapter, List<String> logs) =>
        BleService(onLog: logs.add, onStatusChanged: (_) {}, adapter: adapter);

    List<int> reply(Map<String, dynamic> json) => utf8.encode(jsonEncode(json));

    Map<String, dynamic> chunk(int offset, List<int> bytes) => {
      'offset': offset,
      'data': base64Encode(bytes),
    };

    test('地図情報を取得する', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);
      adapter.responseQueue.add(reply(_infoJson()));

      await service.scanAndConnect();
      final info = await service.pullMapInfo();

      expect(info!.name, 'slam');
      expect(
        jsonDecode(utf8.decode(adapter.written!.expand((c) => c).toList())),
        {'type': 'map_info'},
      );
    });

    test('地図情報が不正なら null', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);
      adapter.responseQueue.add(reply(_infoJson(format: 'jpg')));

      await service.scanAndConnect();

      expect(await service.pullMapInfo(), isNull);
    });

    test('地図データを256 bytesずつ受け取り、進捗とCRCを確認する', () async {
      final adapter = FakeBleAdapter();
      final service = build(adapter, []);
      addTearDown(service.dispose);
      final data = Uint8List.fromList(List.generate(600, (i) => i % 251));
      adapter.responseQueue.addAll([
        reply(chunk(0, data.sublist(0, 256))),
        reply(chunk(256, data.sublist(256, 512))),
        reply(chunk(512, data.sublist(512))),
      ]);
      final info = RobotMapInfo.fromJson({
        ..._infoJson(size: 600),
        'crc32': crc32(data),
      });
      final progress = <int>[];

      await service.scanAndConnect();
      final received = await service.pullMapData(
        info,
        onProgress: (done, total) => progress.add(done),
      );

      expect(received, data);
      expect(progress, [0, 256, 512, 600]);
      expect(
        jsonDecode(utf8.decode(adapter.written!.expand((c) => c).toList())),
        {'type': 'map_chunk', 'offset': 512, 'length': 88},
      );
    });

    test('CRCが違えば null', () async {
      final adapter = FakeBleAdapter();
      final logs = <String>[];
      final service = build(adapter, logs);
      addTearDown(service.dispose);
      adapter.responseQueue.add(reply(chunk(0, [1, 2, 3])));
      final info = RobotMapInfo.fromJson({..._infoJson(size: 3), 'crc32': 1});

      await service.scanAndConnect();

      expect(await service.pullMapData(info), isNull);
      expect(logs.any((l) => l.contains('CRC32')), isTrue);
    });

    test('offsetが違う・空・要求より長い応答は失敗する', () async {
      for (final bad in [
        chunk(8, [1, 2, 3]),
        chunk(0, []),
        chunk(0, List.filled(257, 1)),
        {'offset': 0, 'data': '***'},
        {'offset': 0},
      ]) {
        final adapter = FakeBleAdapter();
        final service = build(adapter, []);
        addTearDown(service.dispose);
        adapter.responseQueue.add(reply(bad));
        final info = RobotMapInfo.fromJson(_infoJson(size: 300));

        await service.scanAndConnect();

        expect(await service.pullMapData(info), isNull, reason: '$bad');
      }
    });
  });

  group('RobotMapReceiver', () {
    late FakeBleConnection conn;
    late List<String> logs;
    late List<MapConfig> added;
    late List<String> deleted;
    var saved = 0;
    var failAdd = false;

    RobotMapReceiver build({bool connected = true}) => RobotMapReceiver(
      connection: conn,
      saveImage: (png) async => '/maps/${saved++}.png',
      deleteImage: (path) async => deleted.add(path),
      addMap: (map) async {
        if (failAdd) throw StateError('db');
        added.add(map);
      },
      isConnected: () => connected,
      onLog: logs.add,
    );

    setUp(() {
      conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
      logs = [];
      added = [];
      deleted = [];
      saved = 0;
      failAdd = false;
    });

    testWidgets('PGMを受け取ってPNGにし、地図として登録する', (tester) async {
      await tester.runAsync(() async {
        final pgm = _pgm(4, 2);
        conn
          ..mapInfo = RobotMapInfo.fromJson(
            _infoJson(format: 'pgm', size: pgm.length),
          )
          ..mapData = pgm;
        final receiver = build();

        expect(await receiver.receive(), isTrue);

        final map = added.single;
        expect(map.name, 'slam');
        expect(map.assetPath, '/maps/0.png');
        expect(map.imageWidth, 4);
        expect(map.imageHeight, 2);
        expect(map.resolution, 0.05);
        expect(map.originX, -10.0);
        expect(map.originY, -5.5);
        expect(receiver.busy, isFalse);
        expect(deleted, isEmpty);
      });
    });

    test('未接続なら何もしない', () async {
      final receiver = build(connected: false);

      expect(receiver.canReceive, isFalse);
      expect(await receiver.receive(), isFalse);
      expect(added, isEmpty);
    });

    test('情報や本体を取得できなければ登録しない', () async {
      final receiver = build();
      expect(await receiver.receive(), isFalse);

      conn.mapInfo = RobotMapInfo.fromJson(_infoJson());
      expect(await receiver.receive(), isFalse);
      expect(added, isEmpty);
    });

    test('PNGとして読めない・寸法が説明と違うときは登録しない', () async {
      conn
        ..mapInfo = RobotMapInfo.fromJson(_infoJson())
        ..mapData = Uint8List.fromList([1, 2, 3]);
      final receiver = build();

      expect(await receiver.receive(), isFalse);
      expect(logs.any((l) => l.contains('画像として読めません')), isTrue);
      expect(added, isEmpty);
    });

    testWidgets('寸法違いのPGMは登録しない', (tester) async {
      await tester.runAsync(() async {
        final pgm = _pgm(3, 3);
        conn
          ..mapInfo = RobotMapInfo.fromJson(
            _infoJson(format: 'pgm', size: pgm.length),
          )
          ..mapData = pgm;
        final receiver = build();

        expect(await receiver.receive(), isFalse);
        expect(logs.any((l) => l.contains('寸法が説明と違います')), isTrue);
        expect(added, isEmpty);
      });
    });

    testWidgets('登録に失敗したら保存した画像を消す', (tester) async {
      await tester.runAsync(() async {
        final pgm = _pgm(4, 2);
        conn
          ..mapInfo = RobotMapInfo.fromJson(
            _infoJson(format: 'pgm', size: pgm.length),
          )
          ..mapData = pgm;
        failAdd = true;
        final receiver = build();

        expect(await receiver.receive(), isFalse);
        expect(deleted, ['/maps/0.png']);
        expect(receiver.busy, isFalse);
      });
    });
  });

  group('地図管理ダイアログの受信ボタン', () {
    Future<void> open(WidgetTester tester, MapReceiveHost? host) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapManagementButton(
              activeMap: BuiltinMaps.gakuseigenkan,
              maps: [BuiltinMaps.gakuseigenkan],
              onSelect: (_) async {},
              onAdd: (_) async {},
              onDelete: (_) async {},
              receiveHost: host,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
    }

    MapReceiveHost host({
      bool can = true,
      double? progress,
      Future<bool> Function()? onReceive,
    }) => MapReceiveHost(
      listenable: ValueNotifier(0),
      canReceive: () => can,
      progress: () => progress,
      onReceive: onReceive ?? () async => true,
    );

    testWidgets('窓口が無ければボタンを出さない', (tester) async {
      await open(tester, null);

      expect(find.byKey(const Key('map-receive')), findsNothing);
    });

    testWidgets('成功したらダイアログを閉じる', (tester) async {
      var calls = 0;
      await open(
        tester,
        host(
          onReceive: () async {
            calls++;
            return true;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('map-receive')));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byKey(const Key('map-receive')), findsNothing);
    });

    testWidgets('失敗したらダイアログを残して知らせる', (tester) async {
      await open(tester, host(onReceive: () async => false));

      await tester.tap(find.byKey(const Key('map-receive')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-receive')), findsOneWidget);
      expect(find.text('地図を受信できませんでした（詳細はログ）'), findsOneWidget);
    });

    testWidgets('未接続では押せず、受信中は進捗を出す', (tester) async {
      await open(tester, host(can: false));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('map-receive')))
            .onPressed,
        isNull,
      );
      expect(find.text('ロボットに接続すると受信できます'), findsOneWidget);
    });

    testWidgets('受信中は進捗バーを出す', (tester) async {
      await open(tester, host(can: false, progress: 0.5));

      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('map-receive-progress')),
            )
            .value,
        0.5,
      );
    });
  });
}
