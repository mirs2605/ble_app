import 'cleaning_zone.dart';

/// 定時清掃ミッション定義モデル。
///
/// 「毎週 [weekdays] の [hour]:[minute] に [zone] を清掃する」という予定を
/// ロボットへ預ける。時刻の判定と開始はロボット側のスケジューラが担い、
/// アプリを閉じていても、スマホが圏外でも動く。
class CleaningScheduleMission {
  static const String wireType = 'cleaning_schedule';

  final int hour;
  final int minute;

  /// 実行する曜日。DateTime.monday(1)〜DateTime.sunday(7)。
  final Set<int> weekdays;
  final CleaningZoneMission zone;

  const CleaningScheduleMission({
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.zone,
  });

  /// 毎日実行する曜日の集合。
  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};

  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() {
    final days = weekdays.toList()..sort();
    return {
      'type': wireType,
      'frame_id': zone.frameId,
      'time': timeText,
      'weekdays': days,
      'polygon': zone.toJson()['polygon'],
    };
  }

  bool get isValid =>
      hour >= 0 &&
      hour <= 23 &&
      minute >= 0 &&
      minute <= 59 &&
      weekdays.isNotEmpty &&
      weekdays.every((d) => d >= DateTime.monday && d <= DateTime.sunday) &&
      zone.isValid;
}

/// ロボットに預けた定時清掃の予定を解除するミッション。
class CleaningScheduleCancel {
  static const String wireType = 'cleaning_schedule_cancel';

  const CleaningScheduleCancel();

  Map<String, dynamic> toJson() => {'type': wireType};
}
