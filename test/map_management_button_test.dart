import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirs_ble_app/models/map_config.dart';
import 'package:mirs_ble_app/widgets/map_management_button.dart';

void main() {
  testWidgets('selecting a saved map invokes the switch action', (
    tester,
  ) async {
    const active = MapConfig(
      id: 1,
      name: '学生会館',
      assetPath: 'assets/maps/gakuseigenkan.png',
      resolution: 0.05,
      originX: -66.619,
      originY: -44.476,
      imageWidth: 2857,
      imageHeight: 1677,
    );
    const other = MapConfig(
      id: 2,
      name: 'MIRS',
      assetPath: 'assets/maps/mirs_map.png',
      resolution: 0.05,
      originX: -3.238,
      originY: -4.542,
      imageWidth: 303,
      imageHeight: 225,
    );
    MapConfig? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapManagementButton(
            activeMap: active,
            maps: const [active, other],
            onSelect: (map) async => selected = map,
            onAdd: (_) async {},
            onDelete: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text(active.name));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, other.name));
    await tester.pumpAndSettle();

    expect(selected, other);
    expect(find.text('地図管理'), findsNothing);
  });
}
