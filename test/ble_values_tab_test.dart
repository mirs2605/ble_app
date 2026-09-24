import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/send_button_state.dart';
import 'package:mirs_ble_app/services/ble_connection.dart';
import 'package:mirs_ble_app/widgets/ble_tabs.dart';

Widget buildTab({
  List<MapPoint> selection = const [],
  ValueChanged<List<MapPoint>>? onSendPolygon,
  bool Function(List<MapPoint>)? canSend,
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
        onStatusPressed: () {},
        sendButtonState: SendButtonState.ready,
      ),
    ),
  );
}

void main() {
  testWidgets('送信ボタンでフォーム値のパース結果が渡される', (tester) async {
    List<MapPoint>? received;
    await tester.pumpWidget(buildTab(onSendPolygon: (p) => received = p));

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(received, const [
      MapPoint(x: 1, y: 1),
      MapPoint(x: 4, y: 1),
      MapPoint(x: 4, y: 3),
      MapPoint(x: 1, y: 3),
    ]);
  });

  testWidgets('地図選択の確定でフォームが同期される', (tester) async {
    await tester.pumpWidget(buildTab());
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '1.0',
    );

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

    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '2.00',
    );
  });

  testWidgets('送信不可のときボタンは無効', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      buildTab(
        canSend: (_) => false,
        onSendPolygon: (_) => pressed = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.send), warnIfMissed: false);
    await tester.pump();

    expect(pressed, isFalse);
  });
}
