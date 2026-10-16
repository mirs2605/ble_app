/// マップ設定のSQLite永続化層。
///
/// - 初回起動時に [BuiltinMaps.all] をシードデータとして挿入する。
/// - アクティブなマップIDは `active_map` テーブルの単一行で管理する。
/// - [activeMap] は常に非null（DBが空なら最初の行を返す）。
library;

import 'package:sqflite/sqflite.dart';

import '../models/map_config.dart';

const _dbName = 'map_config.db';
const _dbVersion = 1;

const _tableMaps = 'maps';
const _tableActive = 'active_map';

class MapConfigRepository {
  MapConfigRepository._();

  static MapConfigRepository? _instance;
  static Database? _db;

  /// シングルトンインスタンスを取得する。[init] の呼び出し後に使用すること。
  static MapConfigRepository get instance {
    assert(_instance != null, 'MapConfigRepository.init() を先に呼んでください');
    return _instance!;
  }

  /// DBを開いてシードデータを挿入し、インスタンスを初期化する。
  /// アプリ起動時に一度だけ呼ぶ。
  static Future<void> init({DatabaseFactory? factory, String? path}) async {
    if (_instance != null) return;
    final openDatabase = factory ?? databaseFactory;
    _db = await openDatabase.openDatabase(
      path ?? _dbName,
      options: OpenDatabaseOptions(version: _dbVersion, onCreate: _onCreate),
    );
    _instance = MapConfigRepository._();
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableMaps (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        asset_path  TEXT    NOT NULL,
        resolution  REAL    NOT NULL,
        origin_x    REAL    NOT NULL,
        origin_y    REAL    NOT NULL,
        image_width REAL    NOT NULL,
        image_height REAL   NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $_tableActive (
        singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
        map_id    INTEGER NOT NULL REFERENCES $_tableMaps(id)
      )
    ''');
    // シードデータ挿入
    int? firstId;
    for (final map in BuiltinMaps.all) {
      final id = await db.insert(_tableMaps, map.toMap());
      firstId ??= id;
    }
    if (firstId != null) {
      await db.insert(_tableActive, {'singleton': 1, 'map_id': firstId});
    }
  }

  Database get _database {
    final db = _db;
    assert(db != null, 'DBが初期化されていません');
    return db!;
  }

  // ─────────────────────────────────────────
  // 読み取り
  // ─────────────────────────────────────────

  /// 登録済みマップ一覧を名前順で返す。
  Future<List<MapConfig>> allMaps() async {
    final rows = await _database.query(_tableMaps, orderBy: 'name ASC');
    return rows.map(MapConfig.fromMap).toList();
  }

  /// 現在アクティブなマップを返す。未設定なら最初のマップを返す。
  Future<MapConfig> activeMap() async {
    final rows = await _database.rawQuery('''
      SELECT m.* FROM $_tableMaps m
      INNER JOIN $_tableActive a ON m.id = a.map_id
      WHERE a.singleton = 1
    ''');
    if (rows.isNotEmpty) {
      return MapConfig.fromMap(rows.first);
    }
    // フォールバック: active_mapが未設定なら最初の行
    final fallback = await _database.query(
      _tableMaps,
      limit: 1,
      orderBy: 'id ASC',
    );
    if (fallback.isEmpty) {
      // DBが完全に空の場合はコード定数を返す
      return BuiltinMaps.gakuseigenkan;
    }
    return MapConfig.fromMap(fallback.first);
  }

  // ─────────────────────────────────────────
  // 書き込み
  // ─────────────────────────────────────────

  /// マップを追加してidを返す。
  Future<MapConfig> addMap(MapConfig config) async {
    if (!config.isValid) {
      throw ArgumentError.value(config, 'config', 'Invalid map configuration');
    }
    if (config.id != null) {
      throw ArgumentError.value(config.id, 'config.id', 'Must be null');
    }
    final id = await _database.insert(_tableMaps, config.toMap());
    return config.copyWith(id: id);
  }

  /// アクティブマップを切り替える。[mapId] は既存マップのIDであること。
  Future<void> setActiveMap(int mapId) async {
    final exists = await _database.query(
      _tableMaps,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [mapId],
      limit: 1,
    );
    if (exists.isEmpty) {
      throw ArgumentError.value(mapId, 'mapId', 'Map does not exist');
    }
    await _database.insert(_tableActive, {
      'singleton': 1,
      'map_id': mapId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// マップを削除する。アクティブなマップは削除できない（例外を投げる）。
  Future<void> deleteMap(int mapId) async {
    final active = await activeMap();
    if (active.id == mapId) {
      throw StateError('アクティブなマップは削除できません');
    }
    await _database.delete(_tableMaps, where: 'id = ?', whereArgs: [mapId]);
  }

  /// テスト用: DBをリセットして再初期化する。
  static Future<void> resetForTest(Database db) async {
    _db = db;
    _instance = MapConfigRepository._();
  }
}
