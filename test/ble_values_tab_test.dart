import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/initial_pose.dart';
import 'package:mirs_ble_app/models/send_button_state.dart';
import 'package:mirs_ble_app/services/ble_connection.dart';
import 'package:mirs_ble_app/widgets/ble_tabs.dart';

Widget buildTab({
  List<MapPoint> selection = const [],
  ValueChanged<List<MapPoint>>? onSendPolygon,
  bool Function(List<MapPoint>)? canSend,
  ValueChanged<InitialPoseMission>? onSendInitialPose,
  bool Function(InitialPoseMission?)? canSendInitialPose,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BleValuesTab(
        status: BleStatus.connected,
        statusAnnouncement: null,
        notice: null,
        selectedMapPoints: selection,
        onSendPolygon: onSendPolygon ?? (_) {},
        canSendPolygon: canSend ?? (_) => true,
        onSendInitialPose: onSendInitialPose ?? (_) {},
        canSendInitialPose: canSendInitialPose ?? (_) => true,
        onStatusPressed: () {},
        sendButtonState: SendButtonState.ready,
      ),
    ),
  );
}

void main() {
  testWidgets('地図選択の確定でフォームが同期される', (tester) async {
    await tester.pumpWidget(buildTab());

    // 清掃範囲フォームの最初のX座標は初期値 1.0
    final initialX = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .firstWhere(
          (w) => w.controller?.text == '1.0',
          orElse: () => throw StateError('X=1.0 フィールドが見つかりません'),
        );
    expect(initialX.controller!.text, '1.0');

    await tester.pumpWidget(
      buildTab(
        selection: const [
          MapPoint(x: 2, y: 2),
          MapPoint(x: 5, y: 2),
          MapPoint(x: 5, y: 4),
          MapPoint(x: 2, y: 4),
        ],
      ),
    );

    // 同期後は 2.00 になる。
    final updatedX = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .firstWhere(
          (w) => w.controller?.text == '2.00',
          orElse: () => throw StateError('X=2.00 フィールドが見つかりません'),
        );
    expect(updatedX.controller!.text, '2.00');
  });

  testWidgets('開始地点フォームの値がonSendInitialPoseへ渡される', (tester) async {
    InitialPoseMission? received;
    await tester.pumpWidget(
      buildTab(onSendInitialPose: (p) => received = p),
    );

    // デフォルト値 0.0 / 0.0 / 0.0 のまま送信ボタンをタップ。
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();

    expect(received, isNotNull);
    expect(received!.x, 0.0);
    expect(received!.y, 0.0);
    expect(received!.yaw, 0.0);
  });

  testWidgets('送信不可のとき開始地点ボタンは無効', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      buildTab(
        canSendInitialPose: (_) => false,
        onSendInitialPose: (_) => pressed = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.my_location), warnIfMissed: false);
    await tester.pump();

    expect(pressed, isFalse);
  });
}
