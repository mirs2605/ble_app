import 'package:flutter_test/flutter_test.dart';
import 'package:mirs_ble_app/models/map_config.dart';
import 'package:mirs_ble_app/services/map_config_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late MapConfigRepository repository;

  setUpAll(() async {
    sqfliteFfiInit();
    await MapConfigRepository.init(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = MapConfigRepository.instance;
  });

  test('seeds built-in maps and persists active map changes', () async {
    final maps = await repository.allMaps();
    expect(maps, hasLength(BuiltinMaps.all.length));
    expect(maps, contains(await repository.activeMap()));

    final added = await repository.addMap(
      const MapConfig(
        name: '追加地図',
        assetPath: '/app/maps/custom.png',
        resolution: 0.1,
        originX: -2,
        originY: -3,
        imageWidth: 1200,
        imageHeight: 800,
      ),
    );
    await repository.setActiveMap(added.id!);
    expect(await repository.activeMap(), added);
  });

  test(
    'rejects invalid configs, unknown map ids, and active map deletion',
    () async {
      await expectLater(
        repository.addMap(
          const MapConfig(
            name: '不正',
            assetPath: '',
            resolution: 0,
            originX: 0,
            originY: 0,
            imageWidth: 0,
            imageHeight: 0,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(repository.setActiveMap(-1), throwsArgumentError);

      final active = await repository.activeMap();
      await expectLater(repository.deleteMap(active.id!), throwsStateError);
    },
  );
}
