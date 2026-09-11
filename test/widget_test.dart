import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/main.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/map_geometry.dart';
import 'package:mirs_ble_app/services/map_selection_controller.dart';
import 'package:mirs_ble_app/services/ble_service.dart';
import 'package:mirs_ble_app/services/permission_service.dart';

void main() {
  testWidgets('displays the BLE client screen', (tester) async {
    await tester.pumpWidget(const MirsBleApp());

    expect(find.byIcon(Icons.map), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
  });

  test('serializes and validates a cleaning zone', () {
    const mission = CleaningZoneMission(
      polygon: [
        MapPoint(x: 1, y: 1),
        MapPoint(x: 4, y: 1),
        MapPoint(x: 4, y: 3),
      ],
    );

    expect(mission.isValid, isTrue);
    expect(mission.toJson(), {
      'type': 'cleaning_zone',
      'frame_id': 'map',
      'polygon': [
        {'x': 1.0, 'y': 1.0},
        {'x': 4.0, 'y': 1.0},
        {'x': 4.0, 'y': 3.0},
      ],
    });
  });

  test('rejects invalid points', () {
    const mission = CleaningZoneMission(
      polygon: [
        MapPoint(x: 0, y: 0),
        MapPoint(x: double.nan, y: 1),
        MapPoint(x: 1, y: 1),
      ],
    );

    expect(mission.isValid, isFalse);
  });

  test('rejects degenerate and self-intersecting polygons', () {
    const zeroArea = CleaningZoneMission(
      polygon: [
        MapPoint(x: 0, y: 0),
        MapPoint(x: 1, y: 0),
        MapPoint(x: 2, y: 0),
      ],
    );
    const bowTie = CleaningZoneMission(
      polygon: [
        MapPoint(x: 0, y: 0),
        MapPoint(x: 2, y: 2),
        MapPoint(x: 0, y: 2),
        MapPoint(x: 2, y: 0),
      ],
    );

    expect(zeroArea.isValid, isFalse);
    expect(bowTie.isValid, isFalse);
  });

  test('rejects duplicate and out-of-range polygon points', () {
    const duplicate = CleaningZoneMission(
      polygon: [
        MapPoint(x: 0, y: 0),
        MapPoint(x: 1, y: 0),
        MapPoint(x: 1, y: 0),
      ],
    );
    const outOfRange = CleaningZoneMission(
      polygon: [
        MapPoint(x: 1000.1, y: 0),
        MapPoint(x: 1001, y: 1),
        MapPoint(x: 1000.1, y: 2),
      ],
    );

    expect(duplicate.isValid, isFalse);
    expect(outOfRange.isValid, isFalse);
  });

  test('converts map coordinates using the full displayed size', () {
    const size = Size(561, 775);
    const point = MapPoint(
      x: MapGeometry.originX + MapGeometry.widthMeters / 2,
      y: MapGeometry.originY + MapGeometry.heightMeters / 2,
    );

    expect(MapGeometry.toScreenPoint(point, size), const Offset(280.5, 387.5));
    expect(
      MapGeometry.fromLocal(const Offset(561, 775), size),
      const MapPoint(
        x: MapGeometry.originX + MapGeometry.widthMeters,
        y: MapGeometry.originY,
      ),
    );
  });

  test('selection controller detects handles across the full map', () {
    const size = Size(561, 775);
    final controller = MapSelectionController()
      ..points = MapGeometry.rectangleFrom(
        const Offset(400, 100),
        const Offset(520, 700),
        size,
      );

    expect(controller.hitHandle(const Offset(520, 700), size), 2);
  });

  test('creates a four-corner polygon that follows a freehand path', () {
    const size = Size(561, 775);
    final controller = MapSelectionController()
      ..updateRectangleFromPath(const [
        Offset(120, 180),
        Offset(280, 120),
        Offset(430, 260),
        Offset(380, 560),
        Offset(140, 500),
      ], size);

    expect(controller.points, hasLength(4));
    expect(controller.points.toSet(), hasLength(4));
    expect(
      controller.points,
      isNot(
        MapGeometry.rectangleFrom(
          const Offset(120, 120),
          const Offset(430, 560),
          size,
        ),
      ),
    );
  });

  test('fits the map inside the available area without distortion', () {
    final wideArea = MapGeometry.fitWithin(const Size(1000, 600));
    expect(wideArea.width, closeTo(434.3225806451613, 0.000001));
    expect(wideArea.height, closeTo(600, 0.000001));

    final tallArea = MapGeometry.fitWithin(const Size(400, 1000));
    expect(tallArea.width, closeTo(400, 0.000001));
    expect(tallArea.height, closeTo(552.5846702310463, 0.000001));
  });

  test('only matches the configured BLE service UUID', () {
    expect(
      BleTargetMatcher.matchesServiceUuid([
        '0000180d-0000-1000-8000-00805f9b34fb',
        BleUuids.serviceUuid.toUpperCase(),
      ]),
      isTrue,
    );
    expect(
      BleTargetMatcher.matchesServiceUuid([
        '0000180d-0000-1000-8000-00805f9b34fb',
      ]),
      isFalse,
    );
  });

  test('requires writable mission and readable response characteristics', () {
    expect(
      BleConnectionRequirements.hasWritableMissionAndReadableResponse(
        missionFound: true,
        missionWritable: true,
        responseFound: true,
        responseReadable: true,
      ),
      isTrue,
    );
    expect(
      BleConnectionRequirements.hasWritableMissionAndReadableResponse(
        missionFound: true,
        missionWritable: false,
        responseFound: true,
        responseReadable: true,
      ),
      isFalse,
    );
    expect(
      BleConnectionRequirements.hasWritableMissionAndReadableResponse(
        missionFound: true,
        missionWritable: true,
        responseFound: false,
        responseReadable: false,
      ),
      isFalse,
    );
  });

  test('splits BLE payloads at the negotiated payload size', () {
    final chunks = BlePayloadChunker.split(List<int>.generate(7, (i) => i), 3);

    expect(chunks, [
      [0, 1, 2],
      [3, 4, 5],
      [6],
    ]);
  });

  test('reconnects only when the service is active and not connected', () {
    expect(
      BleReconnectPolicy.shouldReconnect(
        status: BleStatus.disconnected,
        disposed: false,
      ),
      isTrue,
    );
    expect(
      BleReconnectPolicy.shouldReconnect(
        status: BleStatus.connected,
        disposed: false,
      ),
      isFalse,
    );
    expect(
      BleReconnectPolicy.shouldReconnect(
        status: BleStatus.disconnected,
        disposed: true,
      ),
      isFalse,
    );
  });

  test('accepts only an exact ACK response', () {
    expect(BleResponse.isAccepted([65, 67, 75]), isTrue);
    expect(BleResponse.isAccepted([78, 65, 67, 75]), isFalse);
    expect(BleResponse.isAccepted([255]), isFalse);
  });

  test('preserves permission denial state for the UI', () {
    const result = PermissionRequestResult(
      isGranted: false,
      permanentlyDenied: true,
      deniedNames: ['Permission.bluetoothScan'],
    );

    expect(result.isGranted, isFalse);
    expect(result.permanentlyDenied, isTrue);
    expect(result.deniedNames, contains('Permission.bluetoothScan'));
  });
}
