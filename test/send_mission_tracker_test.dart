import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/controllers/send_mission_tracker.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/send_button_state.dart';

List<MapPoint> _quad() => const [
  MapPoint(x: 1, y: 1),
  MapPoint(x: 4, y: 1),
  MapPoint(x: 4, y: 3),
  MapPoint(x: 1, y: 3),
];

void main() {
  test('初期状態は送信可能チェックのみ行う', () {
    final tracker = SendMissionTracker();
    expect(tracker.buttonState, SendButtonState.ready);
    expect(tracker.canSend(_quad()), isTrue);
    expect(tracker.canSend(const [MapPoint(x: 1, y: 1)]), isFalse);
  });

  test('begin→succeedで完了し同一範囲の再送を抑止する', () {
    final tracker = SendMissionTracker()..beginSend();
    expect(tracker.buttonState, SendButtonState.sending);

    tracker.succeed(_quad());
    expect(tracker.buttonState, SendButtonState.completed);
    expect(tracker.canSend(_quad()), isFalse);
    expect(
      tracker.canSend(const [
        MapPoint(x: 2, y: 2),
        MapPoint(x: 5, y: 2),
        MapPoint(x: 5, y: 4),
        MapPoint(x: 2, y: 4),
      ]),
      isTrue,
    );
  });

  test('failでは完了にならず再送できる', () {
    final tracker = SendMissionTracker()
      ..beginSend()
      ..failSend();
    expect(tracker.buttonState, SendButtonState.ready);
    expect(tracker.canSend(_quad()), isTrue);
  });

  test('markSendingは完了フラグに触れない', () {
    final tracker = SendMissionTracker()
      ..succeed(_quad())
      ..markSending();
    expect(tracker.buttonState, SendButtonState.completed);
  });

  test('resetProgressで進行状態は戻るが送信履歴は保持する', () {
    final tracker = SendMissionTracker()
      ..succeed(_quad())
      ..resetProgress();
    expect(tracker.buttonState, SendButtonState.ready);
    // 選択変更後も同一範囲の再送抑止は継続する（従来のControllerと同等）。
    expect(tracker.canSend(_quad()), isFalse);
    expect(
      tracker.canSend(const [
        MapPoint(x: 2, y: 2),
        MapPoint(x: 5, y: 2),
        MapPoint(x: 5, y: 4),
        MapPoint(x: 2, y: 4),
      ]),
      isTrue,
    );
  });
}
