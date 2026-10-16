import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/initial_pose.dart';
import 'package:mirs_ble_app/models/map_edit_mode.dart';
import 'package:mirs_ble_app/services/map_selection_controller.dart';
import 'package:mirs_ble_app/widgets/map_selection_area.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 400, height: 600, child: child),
  ),
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

  testWidgets('開始地点モードで右ドラッグするとyaw=0で確定する', (tester) async {
    InitialPoseMission? confirmed;
    await tester.pumpWidget(
      _wrap(
        MapSelectionArea(
          controller: MapSelectionController(),
          onChanged: (_) {},
          editMode: MapEditMode.initialPose,
          onPoseChanged: (pose) => confirmed = pose,
        ),
      ),
    );
    await tester.pump();

    final center = tester.getCenter(find.byType(MapSelectionArea));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(center + const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    expect(confirmed, isNotNull);
    expect(confirmed!.yaw, closeTo(0.0, 1e-6));
    expect(confirmed!.isValid, isTrue);
  });

  testWidgets('開始地点モードの短いタップは位置だけ確定する', (tester) async {
    InitialPoseMission? confirmed;
    await tester.pumpWidget(
      _wrap(
        MapSelectionArea(
          controller: MapSelectionController(),
          onChanged: (_) {},
          editMode: MapEditMode.initialPose,
          onPoseChanged: (pose) => confirmed = pose,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(MapSelectionArea));
    await tester.pump();

    expect(confirmed, isNotNull);
    expect(confirmed!.yaw, 0.0);
  });
}
