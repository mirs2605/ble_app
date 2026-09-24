import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/send_button_state.dart';
import 'package:mirs_ble_app/widgets/mission_send_button.dart';

Widget buildButton(
  SendButtonState state, {
  bool enabled = true,
  VoidCallback? onPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: MissionSendButton(
          heroTag: 'test-send',
          enabled: enabled,
          onPressed: onPressed ?? () {},
          state: state,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('ready時は送信アイコンの丸ボタン', (tester) async {
    await tester.pumpWidget(buildButton(SendButtonState.ready));
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.text('送信完了'), findsNothing);
  });

  testWidgets('completed時は文言なしでチェック丸ボタンのみ', (tester) async {
    await tester.pumpWidget(buildButton(SendButtonState.ready));

    await tester.pumpWidget(buildButton(SendButtonState.completed));
    // アニメーション途中もチェックアイコンである。
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // 完了文言は通知バーに任せ、ボタンには出さない。
    expect(find.text('送信完了'), findsNothing);
  });

  testWidgets('completedタップはonPressedに委ねる', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      buildButton(SendButtonState.completed, onPressed: () => pressed = true),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();

    expect(pressed, isTrue);
  });

  testWidgets('sending時は文言なしでリングカーソルのみ', (tester) async {
    await tester.pumpWidget(buildButton(SendButtonState.sending));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('送信中'), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('送信中はタップを受け付けない', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      buildButton(SendButtonState.sending, onPressed: () => pressed = true),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(MissionSendButton), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));

    expect(pressed, isFalse);
  });
}
