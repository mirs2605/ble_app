import '../models/cleaning_zone.dart';
import '../models/send_button_state.dart';

/// 送信フローの進行状態。UI文言もタイマーも持たない純粋な状態遷移。
/// begin → succeed/fail、選択変更時は resetProgress。
class SendMissionTracker {
  bool isSending = false;
  bool sendCompleted = false;
  List<MapPoint>? _lastSent;

  List<MapPoint>? get lastSent =>
      _lastSent == null ? null : List<MapPoint>.unmodifiable(_lastSent!);

  SendButtonState get buttonState {
    if (sendCompleted) return SendButtonState.completed;
    if (isSending) return SendButtonState.sending;
    return SendButtonState.ready;
  }

  /// 送信ボタン活性条件（接続状態はController側で判定）。
  /// 点数基準は [CleaningZoneMission.minPoints] に一元化。
  bool canSend(List<MapPoint> points) =>
      points.length >= CleaningZoneMission.minPoints &&
      !_samePoints(points, _lastSent);

  void beginSend() {
    isSending = true;
    sendCompleted = false;
  }

  /// BLE層からのsending通知用。完了フラグには触れない。
  void markSending() {
    isSending = true;
  }

  void succeed(List<MapPoint> sent) {
    isSending = false;
    sendCompleted = true;
    _lastSent = List<MapPoint>.from(sent);
  }

  void failSend() {
    isSending = false;
  }

  void resetProgress() {
    isSending = false;
    sendCompleted = false;
  }

  static bool _samePoints(List<MapPoint> points, List<MapPoint>? other) {
    if (other == null || points.length != other.length) return false;
    for (var i = 0; i < points.length; i++) {
      if (points[i] != other[i]) return false;
    }
    return true;
  }
}
