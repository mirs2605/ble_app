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
          MapPoint(x: 3.5, y: 2),
          MapPoint(x: 5, y: 3),
          MapPoint(x: 5, y: 4),
          MapPoint(x: 3.5, y: 4),
          MapPoint(x: 2, y: 3),
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
}
