/// 定時清掃の予定のSQLite永続化層。
///
/// 削除済みの予定（墓標）も保持する。同期で相手側の古い行が復活するのを防ぐため。
/// 画面に出すときは呼び出し側で [ScheduleEntry.deleted] を除く。
library;

import 'package:sqflite/sqflite.dart';

import '../models/schedule_entry.dart';

const _dbName = 'schedules.db';
const _dbVersion = 1;
const _table = 'schedules';

class ScheduleRepository {
  ScheduleRepository._(this._db);

  final Database _db;

  /// DBを開く。アプリ起動時に一度だけ呼ぶ。
  /// [singleInstance] を false にすると、同じパスでも別のDBとして開く
  /// （テストで複数のメモリDBを同時に使うため）。
  static Future<ScheduleRepository> open({
    DatabaseFactory? factory,
    String? path,
    bool singleInstance = true,
  }) async {
    final openDatabase = factory ?? databaseFactory;
    final db = await openDatabase.openDatabase(
      path ?? _dbName,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        singleInstance: singleInstance,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE $_table (
            id       TEXT    PRIMARY KEY,
            revision INTEGER NOT NULL,
            deleted  INTEGER NOT NULL,
            enabled  INTEGER NOT NULL,
            hour     INTEGER NOT NULL,
            minute   INTEGER NOT NULL,
            weekdays TEXT    NOT NULL,
            frame_id TEXT    NOT NULL,
            polygon  TEXT    NOT NULL
          )
        '''),
      ),
    );
    return ScheduleRepository._(db);
  }

  /// 墓標を含む全件を、時刻順で返す。
  Future<List<ScheduleEntry>> all() async {
    final rows = await _db.query(_table, orderBy: 'hour, minute, id');
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  Future<ScheduleEntry?> get(String id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ScheduleEntry.fromMap(rows.first);
  }

  /// 同じidの行を置き換えて保存する。
  Future<void> saveAll(Iterable<ScheduleEntry> entries) async {
    final batch = _db.batch();
    for (final entry in entries) {
      batch.insert(
        _table,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> save(ScheduleEntry entry) => saveAll([entry]);

  Future<void> close() => _db.close();
}
