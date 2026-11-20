import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cleaning_zone.dart';

/// 定時清掃の予定1件。スマホとロボットの DB が同じ形で持つ。
///
/// 「毎週 [weekdays] の [hour]:[minute] に [zone] を清掃する」という内容に、
/// 同期のための [id]・[revision]・[deleted] を足したもの。
/// 時刻の判定と開始はロボット側のスケジューラが担う。
///
/// 削除は行を消さず [deleted] を立てる（墓標）。そうしないと、
/// 相手側に残った古い行が次の同期で復活してしまう。
class ScheduleEntry {
  static const int maxIdLength = 64;
  static const int maxEntries = 32;

  final String id;

  /// 編集のたびに 1 ずつ増える更新番号。同期では大きい方を採用する。
  final int revision;
  final bool deleted;
  final bool enabled;
  final int hour;
  final int minute;

  /// 実行する曜日。DateTime.monday(1)〜DateTime.sunday(7)。
  final Set<int> weekdays;

  /// 清掃範囲。頂点は開路（末尾=始点の重複なし）で保持する。
  final CleaningZoneMission zone;

  const ScheduleEntry({
    required this.id,
    required this.revision,
    this.deleted = false,
    this.enabled = true,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.zone,
  });

  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};

  /// 新しい予定を作る（更新番号 1）。
  factory ScheduleEntry.create({
    required String id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required List<MapPoint> polygon,
    bool enabled = true,
  }) => ScheduleEntry(
    id: id,
    revision: 1,
    enabled: enabled,
    hour: hour,
    minute: minute,
    weekdays: Set.unmodifiable(weekdays),
    zone: CleaningZoneMission(polygon: openRing(polygon)),
  );

  /// 閉路表現（末尾が始点と一致）なら末尾を除いた開路にする。
  static List<MapPoint> openRing(List<MapPoint> polygon) {
    final points = List<MapPoint>.of(polygon);
    if (points.length > 1 && points.first == points.last) {
      points.removeLast();
    }
    return points;
  }

  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 内容を変えずに更新番号だけ進めた写し。編集・削除はこれで作る。
  ScheduleEntry edited({bool? enabled, bool? deleted}) => ScheduleEntry(
    id: id,
    revision: revision + 1,
    deleted: deleted ?? this.deleted,
    enabled: enabled ?? this.enabled,
    hour: hour,
    minute: minute,
    weekdays: weekdays,
    zone: zone,
  );

  bool get isValid {
    if (id.isEmpty || id.length > maxIdLength || revision < 1) return false;
    if (deleted) return true;
    return hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59 &&
        weekdays.isNotEmpty &&
        weekdays.every((d) => d >= DateTime.monday && d <= DateTime.sunday) &&
        zone.isValid;
  }

  /// 有線形式（ロボットとの契約）。ポリゴンは閉路で送る。
  Map<String, dynamic> toJson() {
    final days = weekdays.toList()..sort();
    return {
      'id': id,
      'revision': revision,
      'deleted': deleted,
      'enabled': enabled,
      'frame_id': zone.frameId,
      'time': timeText,
      'weekdays': days,
      'polygon': zone.toJson()['polygon'],
    };
  }

  /// ロボットから受け取った JSON を読む。不正なら [FormatException]。
  /// 削除済みの行は時刻・曜日・範囲が欠けていてもよい。
  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final revision = json['revision'];
    if (id is! String || revision is! int) {
      throw const FormatException(
        'schedule requires string id and int revision',
      );
    }
    final deleted = json['deleted'] == true;
    final entry = deleted
        ? ScheduleEntry(
            id: id,
            revision: revision,
            deleted: true,
            enabled: json['enabled'] != false,
            hour: 0,
            minute: 0,
            weekdays: const {},
            zone: const CleaningZoneMission(polygon: []),
          )
        : _fromLiveJson(id, revision, json);
    if (!entry.isValid) {
      throw FormatException('invalid schedule: $id');
    }
    return entry;
  }

  static ScheduleEntry _fromLiveJson(
    String id,
    int revision,
    Map<String, dynamic> json,
  ) {
    final time = json['time'];
    final match = time is String
        ? RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time)
        : null;
    final days = json['weekdays'];
    final polygon = json['polygon'];
    if (match == null || days is! List || polygon is! List) {
      throw const FormatException('schedule requires time, weekdays, polygon');
    }
    return ScheduleEntry(
      id: id,
      revision: revision,
      enabled: json['enabled'] != false,
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
      weekdays: Set.unmodifiable(days.whereType<int>()),
      zone: CleaningZoneMission(
        frameId: (json['frame_id'] as String?) ?? 'map',
        polygon: openRing([
          for (final p in polygon)
            MapPoint.fromJson(Map<String, dynamic>.from(p as Map)),
        ]),
      ),
    );
  }

  /// SQLite の 1 行へ。
  Map<String, Object?> toMap() => {
    'id': id,
    'revision': revision,
    'deleted': deleted ? 1 : 0,
    'enabled': enabled ? 1 : 0,
    'hour': hour,
    'minute': minute,
    'weekdays': (weekdays.toList()..sort()).join(','),
    'frame_id': zone.frameId,
    'polygon': jsonEncode([for (final p in zone.polygon) p.toJson()]),
  };

  factory ScheduleEntry.fromMap(Map<String, Object?> map) {
    final weekdays = (map['weekdays'] as String)
        .split(',')
        .where((s) => s.isNotEmpty)
        .map(int.parse);
    final polygon = (jsonDecode(map['polygon'] as String) as List).map(
      (p) => MapPoint.fromJson(Map<String, dynamic>.from(p as Map)),
    );
    return ScheduleEntry(
      id: map['id'] as String,
      revision: map['revision'] as int,
      deleted: map['deleted'] == 1,
      enabled: map['enabled'] == 1,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      weekdays: Set.unmodifiable(weekdays),
      zone: CleaningZoneMission(
        frameId: map['frame_id'] as String,
        polygon: polygon.toList(),
      ),
    );
  }

  /// 同期での内容比較。更新番号が同じ行が食い違っていないかを見る。
  @override
  bool operator ==(Object other) =>
      other is ScheduleEntry &&
      other.id == id &&
      other.revision == revision &&
      other.deleted == deleted &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute &&
      setEquals(other.weekdays, weekdays) &&
      other.zone.frameId == zone.frameId &&
      listEquals(other.zone.polygon, zone.polygon);

  @override
  int get hashCode => Object.hash(
    id,
    revision,
    deleted,
    enabled,
    hour,
    minute,
    Object.hashAll(weekdays),
    Object.hashAll(zone.polygon),
  );

  @override
  String toString() =>
      'ScheduleEntry($id r$revision ${deleted ? 'deleted' : timeText})';
}
