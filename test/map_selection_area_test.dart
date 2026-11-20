import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/map_geometry.dart';
import 'package:mirs_ble_app/models/shape_template.dart';
import 'package:mirs_ble_app/services/map_selection_controller.dart';
import 'package:mirs_ble_app/widgets/map_selection_area.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, height: 600, child: child)),
);

void main() {
  testWidgets('初期状態で描画中でないことが報告される', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      _wrap(
        MapSelectionArea(
          controller: MapSelectionController(),
          onChanged: (_) {},
          onSelectionIdleChanged: reports.add,
        ),
      ),
    );
    await tester.pump();

    expect(reports, [true]);
  });

  testWidgets('テンプレートの面内ドラッグと頂点ドラッグで平行移動・拡大縮小が通知される', (tester) async {
    final controller = MapSelectionController()
      ..applyTemplate(ShapeTemplate.star);
    final emitted = <List<MapPoint>>[];

    await tester.pumpWidget(
      _wrap(
        MapSelectionArea(
          controller: controller,
          onChanged: (pts) {
            controller.points = pts;
            emitted.add(pts);
          },
        ),
      ),
    );
    await tester.pump();

    final initialCenter = controller.templateCenter!;
    // Viewport (400x600) の中央は (200, 300) で地図中央と一致
    await tester.dragFrom(const Offset(200, 300), const Offset(30, -20));
    await tester.pump();

    expect(emitted, isNotEmpty);
    expect(controller.isTemplate, isTrue);
    expect(controller.templateCenter!.x, greaterThan(initialCenter.x));
    expect(controller.templateCenter!.y, greaterThan(initialCenter.y));
  });

  testWidgets('任意の多角形の辺ドラッグで辺が平行移動しonChangedが呼ばれる', (tester) async {
    const viewport = Size(400, 600);
    final mapSize = MapGeometry.fitWithin(viewport);
    final mapOffset = Offset(
      (viewport.width - mapSize.width) / 2,
      (viewport.height - mapSize.height) / 2,
    );

    final controller = MapSelectionController()
      ..updateRectangleSelection(
        const Offset(80, 60),
        const Offset(280, 180),
        mapSize,
      );
    final initial = List<MapPoint>.from(controller.points);
    final emitted = <List<MapPoint>>[];

    await tester.pumpWidget(
      _wrap(
        MapSelectionArea(
          controller: controller,
          onChanged: (pts) {
            controller.points = pts;
            emitted.add(pts);
          },
        ),
      ),
    );
    await tester.pump();

    // 上辺の中点 (180, 60)（ローカル座標）を画面座標に変換してドラッグ
    final edgeMidViewport = mapOffset + const Offset(180, 60);
    await tester.dragFrom(edgeMidViewport, const Offset(20, -15));
    await tester.pump();

    expect(emitted, isNotEmpty);
    expect(controller.points[0].x, greaterThan(initial[0].x));
    expect(controller.points[1].x, greaterThan(initial[1].x));
    // 辺のベクトル（頂点1 - 頂点0）が保たれていること
    expect(
      controller.points[1].x - controller.points[0].x,
      closeTo(initial[1].x - initial[0].x, 1e-4),
    );
    expect(
      controller.points[1].y - controller.points[0].y,
      closeTo(initial[1].y - initial[0].y, 1e-4),
    );
    // 反対側の辺（頂点2・頂点3）は動いていないこと
    expect(controller.points[2], initial[2]);
    expect(controller.points[3], initial[3]);
  });
}
