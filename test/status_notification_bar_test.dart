import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/widgets/status_notification_bar.dart';

Widget buildBar(String? message) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: StatusNotificationBar(message: message),
      ),
    ),
  );
}

Size barSize(WidgetTester tester) =>
    tester.getSize(find.byType(StatusNotificationBar));

void main() {
  testWidgets('文言の長さに合わせて伸縮し省略しない', (tester) async {
    await tester.pumpWidget(buildBar('短い'));
    await tester.pumpAndSettle();
    final narrow = barSize(tester).width;
    expect(find.text('短い'), findsOneWidget);

    await tester.pumpWidget(buildBar('少し長いメッセージです'));
    await tester.pumpAndSettle();
    final wide = barSize(tester).width;
    expect(wide, greaterThan(narrow));
    // 省略記号にならず全文表示される。
    expect(find.text('少し長いメッセージです'), findsOneWidget);

    await tester.pumpWidget(buildBar('短い'));
    await tester.pumpAndSettle();
    expect(barSize(tester).width, narrow);
  });

  testWidgets('非表示時はレイアウトから除外される', (tester) async {
    await tester.pumpWidget(buildBar('表示'));
    await tester.pumpAndSettle();
    expect(barSize(tester).width, greaterThan(0));

    await tester.pumpWidget(buildBar(null));
    await tester.pumpAndSettle();
    expect(barSize(tester).width, 0);
  });
}
