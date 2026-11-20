import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/map_config.dart';
import 'package:mirs_ble_app/models/map_geometry.dart';
import 'package:mirs_ble_app/models/shape_template.dart';
import 'package:mirs_ble_app/services/map_selection_controller.dart';

void main() {
  for (final template in ShapeTemplate.all) {
    group(template.label, () {
      test('頂点数が上限以内で、送信検証を通る', () {
        expect(
          template.vertexCount,
          lessThanOrEqualTo(MapGeometry.maxFreehandVertexCount),
        );
        final mission = CleaningZoneMission(polygon: template.placeOn());
        expect(mission.isValid, isTrue);
      });

      test('配置した頂点が地図の範囲内に収まる', () {
        const config = BuiltinMaps.gakuseigenkan;
        for (final p in template.placeOn(config)) {
          expect(
            p.x,
            inInclusiveRange(
              config.originX,
              config.originX + config.widthMeters,
            ),
          );
          expect(
            p.y,
            inInclusiveRange(
              config.originY,
              config.originY + config.heightMeters,
            ),
          );
        }
      });
    });
  }

  group('テンプレートと任意多角形の編集操作', () {
    const size = Size(561, 775);

    test('テンプレートの頂点ドラッグで中心基準の拡大縮小ができる', () {
      final controller = MapSelectionController()
        ..applyTemplate(ShapeTemplate.star);
      expect(controller.isTemplate, isTrue);

      final initialPoints = List<MapPoint>.from(controller.points);
      final center = controller.templateCenter!;
      final handleScreen = MapGeometry.toScreenPoint(initialPoints[0], size);
      final centerScreen = MapGeometry.toScreenPoint(center, size);

      // 中心から頂点0への距離を半分にする位置へドラッグ（0.5倍に縮小）
      final halfScreen = Offset.lerp(centerScreen, handleScreen, 0.5)!;
      expect(controller.startGesture(handleScreen, size), isTrue);
      expect(controller.isDraggingHandle, isTrue);
      expect(controller.moveActiveSelection(halfScreen, size), isTrue);

      for (int i = 0; i < initialPoints.length; i++) {
        final expectedX = center.x + (initialPoints[i].x - center.x) * 0.5;
        final expectedY = center.y + (initialPoints[i].y - center.y) * 0.5;
        expect(controller.points[i].x, closeTo(expectedX, 1e-4));
        expect(controller.points[i].y, closeTo(expectedY, 1e-4));
      }
      expect(CleaningZoneMission(polygon: controller.points).isValid, isTrue);
    });

    test('テンプレートの面内ドラッグで平行移動でき、移動後も中心基準で拡大縮小できる', () {
      final controller = MapSelectionController()
        ..applyTemplate(ShapeTemplate.cross);
      final initialPoints = List<MapPoint>.from(controller.points);
      final initialCenter = controller.templateCenter!;
      final centerScreen = MapGeometry.toScreenPoint(initialCenter, size);

      // 面の中央をドラッグして平行移動
      const deltaScreen = Offset(40, -30);
      expect(controller.startGesture(centerScreen, size), isTrue);
      expect(controller.isDraggingFace, isTrue);
      expect(
        controller.moveActiveSelection(centerScreen + deltaScreen, size),
        isTrue,
      );
      controller.finishGesture(const [], size, wasTransforming: false);

      final expectedDelta = MapGeometry.screenDeltaToMeters(deltaScreen, size);
      for (int i = 0; i < initialPoints.length; i++) {
        expect(
          controller.points[i].x,
          closeTo(initialPoints[i].x + expectedDelta.dx, 1e-4),
        );
        expect(
          controller.points[i].y,
          closeTo(initialPoints[i].y + expectedDelta.dy, 1e-4),
        );
      }

      // 移動後の新しい中心を基準に拡大縮小されることを確認
      final movedPoints = List<MapPoint>.from(controller.points);
      final movedCenter = controller.templateCenter!;
      expect(movedCenter.x, closeTo(initialCenter.x + expectedDelta.dx, 1e-4));
      expect(movedCenter.y, closeTo(initialCenter.y + expectedDelta.dy, 1e-4));

      final handle0Screen = MapGeometry.toScreenPoint(movedPoints[0], size);
      final movedCenterScreen = MapGeometry.toScreenPoint(movedCenter, size);
      final scaledScreen = Offset.lerp(movedCenterScreen, handle0Screen, 0.8)!;

      expect(controller.startGesture(handle0Screen, size), isTrue);
      expect(controller.moveActiveSelection(scaledScreen, size), isTrue);
      for (int i = 0; i < movedPoints.length; i++) {
        final expectedX =
            movedCenter.x + (movedPoints[i].x - movedCenter.x) * 0.8;
        final expectedY =
            movedCenter.y + (movedPoints[i].y - movedCenter.y) * 0.8;
        expect(controller.points[i].x, closeTo(expectedX, 1e-4));
        expect(controller.points[i].y, closeTo(expectedY, 1e-4));
      }
    });

    test('任意の多角形で辺をドラッグするとその辺の両端が平行移動する', () {
      final controller = MapSelectionController()
        ..updateRectangleSelection(
          const Offset(100, 150),
          const Offset(300, 450),
          size,
        );
      expect(controller.isTemplate, isFalse);
      final initial = List<MapPoint>.from(controller.points);

      // 上辺（頂点0: (100,150) と 頂点1: (300,150) の中点 (200,150)）を掴んで移動
      const edgeMidpoint = Offset(200, 150);
      const dragDelta = Offset(25, -40);
      expect(controller.startGesture(edgeMidpoint, size), isTrue);
      expect(controller.isDraggingEdge, isTrue);
      expect(controller.activeEdgeIndex, 0);
      expect(
        controller.moveActiveSelection(edgeMidpoint + dragDelta, size),
        isTrue,
      );

      final deltaMeters = MapGeometry.screenDeltaToMeters(dragDelta, size);
      // 辺0の両端（頂点0・頂点1）が同じ移動量だけ平行移動する
      expect(
        controller.points[0].x,
        closeTo(initial[0].x + deltaMeters.dx, 1e-4),
      );
      expect(
        controller.points[0].y,
        closeTo(initial[0].y + deltaMeters.dy, 1e-4),
      );
      expect(
        controller.points[1].x,
        closeTo(initial[1].x + deltaMeters.dx, 1e-4),
      );
      expect(
        controller.points[1].y,
        closeTo(initial[1].y + deltaMeters.dy, 1e-4),
      );
      // 他の頂点（頂点2・頂点3）は動かない
      expect(controller.points[2], initial[2]);
      expect(controller.points[3], initial[3]);
    });

    test('任意の多角形で面内をドラッグすると面全体が平行移動する', () {
      final controller = MapSelectionController()
        ..updateRectangleSelection(
          const Offset(100, 150),
          const Offset(300, 450),
          size,
        );
      final initial = List<MapPoint>.from(controller.points);

      const insidePoint = Offset(200, 300);
      const dragDelta = Offset(30, 50);
      expect(controller.startGesture(insidePoint, size), isTrue);
      expect(controller.isDraggingFace, isTrue);
      expect(
        controller.moveActiveSelection(insidePoint + dragDelta, size),
        isTrue,
      );

      final deltaMeters = MapGeometry.screenDeltaToMeters(dragDelta, size);
      for (int i = 0; i < initial.length; i++) {
        expect(
          controller.points[i].x,
          closeTo(initial[i].x + deltaMeters.dx, 1e-4),
        );
        expect(
          controller.points[i].y,
          closeTo(initial[i].y + deltaMeters.dy, 1e-4),
        );
      }
    });
  });
}
