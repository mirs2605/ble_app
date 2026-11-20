import 'package:mirs_ble_app/controllers/map_catalog.dart';
import 'package:mirs_ble_app/models/map_config.dart';
import 'package:mirs_ble_app/services/map_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';

MapConfig _map(String name, {int? id}) => MapConfig(
  id: id,
  name: name,
  assetPath: 'assets/maps/$name.png',
  resolution: 0.05,
  originX: 0,
  originY: 0,
  imageWidth: 100,
  imageHeight: 100,
);

/// DB を使わないインメモリのリポジトリ。
class _FakeRepo implements MapConfigRepository {
  final maps = <MapConfig>[BuiltinMaps.gakuseigenkan];
  int activeId = 1;
  int _nextId = 100;

  @override
  Future<MapConfig> activeMap() async =>
      maps.firstWhere((m) => m.id == activeId, orElse: () => maps.first);

  @override
  Future<List<MapConfig>> allMaps() async => List.of(maps);

  @override
  Future<void> setActiveMap(int id) async => activeId = id;

  @override
  Future<MapConfig> addMap(MapConfig config) async {
    final saved = config.copyWith(id: _nextId++);
    maps.add(saved);
    return saved;
  }

  @override
  Future<void> deleteMap(int id) async {
    if (id == activeId) throw StateError('アクティブな地図は削除できません');
    maps.removeWhere((m) => m.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepo repo;
  late MapCatalog catalog;

  setUp(() {
    repo = _FakeRepo();
    catalog = MapCatalog(repository: repo);
  });

  tearDown(() => catalog.dispose());

  test('add はアクティブにして一覧へ反映し、通知する', () async {
    var notified = 0;
    catalog.addListener(() => notified++);

    final ok = await catalog.add(_map('B'));

    expect(ok, isTrue);
    expect(catalog.active.name, 'B');
    expect(catalog.all.length, 2);
    expect(notified, 1);
  });

  test('id のない地図への switchTo は何もしない', () async {
    final ok = await catalog.switchTo(_map('X'));
    expect(ok, isFalse);
  });

  test('アクティブな地図の delete は理由を返す', () async {
    await catalog.add(_map('B'));
    final error = await catalog.delete(catalog.active);
    expect(error, isNotNull);
    expect(catalog.all.length, 2);
  });
}
