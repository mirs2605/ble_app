import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/schedule_entry.dart';
import 'package:mirs_ble_app/widgets/schedule_dialog.dart';

ScheduleEntry _entry(String id, {bool enabled = true}) => ScheduleEntry(
  id: id,
  revision: 1,
  enabled: enabled,
  hour: 6,
  minute: 5,
  weekdays: ScheduleEntry.everyDay,
  zone: const CleaningZoneMission(
    polygon: [MapPoint(x: 1, y: 1), MapPoint(x: 4, y: 1), MapPoint(x: 4, y: 3)],
  ),
);

Future<void> _open(WidgetTester tester, ScheduleDialogHost host) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showScheduleDialog(context, host),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('予定の一覧・切替・削除・同期・追加が窓口へ伝わる', (tester) async {
    final calls = <String>[];
    final host = ScheduleDialogHost(
      listenable: ValueNotifier(0),
      entries: () => [_entry('a')],
      canAdd: () => true,
      canSync: () => true,
      onAdd: (h, m, days) async => calls.add('add $h:$m ${days.length}'),
      onToggle: (id, on) async => calls.add('toggle $id $on'),
      onDelete: (id) async => calls.add('delete $id'),
      onSync: () async => calls.add('sync'),
    );
    await _open(tester, host);

    expect(find.text('06:05'), findsOneWidget);
    expect(find.text('毎日'), findsOneWidget);

    await tester.tap(find.byKey(const Key('schedule-toggle-a')));
    await tester.tap(find.byKey(const Key('schedule-delete-a')));
    await tester.tap(find.byKey(const Key('schedule-sync')));
    await tester.tap(find.byKey(const Key('schedule-add')));
    await tester.pump();

    expect(calls, ['toggle a false', 'delete a', 'sync', 'add 9:0 7']);
  });

  testWidgets('範囲が無い・曜日が空・未接続のときは押せない', (tester) async {
    final host = ScheduleDialogHost(
      listenable: ValueNotifier(0),
      entries: () => [],
      canAdd: () => false,
      canSync: () => false,
      onAdd: (h, m, days) async {},
      onToggle: (id, on) async {},
      onDelete: (id) async {},
      onSync: () async {},
    );
    await _open(tester, host);

    expect(find.text('予定はまだありません'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('schedule-add')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('schedule-sync')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('曜日をすべて外すと追加できない', (tester) async {
    final host = ScheduleDialogHost(
      listenable: ValueNotifier(0),
      entries: () => [],
      canAdd: () => true,
      canSync: () => true,
      onAdd: (h, m, days) async {},
      onToggle: (id, on) async {},
      onDelete: (id) async {},
      onSync: () async {},
    );
    await _open(tester, host);

    for (var d = 1; d <= 7; d++) {
      await tester.tap(find.byKey(Key('schedule-weekday-$d')));
    }
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('schedule-add')))
          .onPressed,
      isNull,
    );
  });
}
