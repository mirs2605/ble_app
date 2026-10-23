import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirs_ble_app/models/map_config.dart';
import 'package:mirs_ble_app/services/map_image_storage.dart';
import 'package:mirs_ble_app/widgets/map_management_button.dart';

class FakeMapImageStorage extends MapImageStorage {
  final List<String> deletedPaths = [];

  @override
  Future<void> delete(String path) async => deletedPaths.add(path);
}

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

void main() {
  testWidgets('deleting a map removes its image through the storage', (
    tester,
  ) async {
    final storage = FakeMapImageStorage();
    MapConfig? deleted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapManagementButton(
            activeMap: active,
            maps: const [active, other],
            onSelect: (_) async {},
            onAdd: (_) async {},
            onDelete: (map) async => deleted = map,
            imageStorage: storage,
          ),
        ),
      ),
    );

    await tester.tap(find.text(active.name));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(deleted, other);
    expect(storage.deletedPaths, [other.assetPath]);
  });

  testWidgets('selecting a saved map invokes the switch action', (
    tester,
  ) async {
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
