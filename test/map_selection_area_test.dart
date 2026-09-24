import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/services/map_selection_controller.dart';
import 'package:mirs_ble_app/widgets/map_selection_area.dart';

void main() {
  testWidgets('初期状態で描画中でないことが報告される', (tester) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: MapSelectionArea(
              controller: MapSelectionController(),
              onChanged: (_) {},
              onSelectionIdleChanged: reports.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(reports, [true]);
  });
}
