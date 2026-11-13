import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/schedule_dialog_host.dart';
import 'package:mirs_ble_app/models/schedule_entry.dart';
import 'package:mirs_ble_app/services/ble_connection.dart';
import 'package:mirs_ble_app/widgets/ble_tabs.dart';

ScheduleEntry _entry(String id) => ScheduleEntry(
  id: id,
  revision: 1,
  enabled: true,
  hour: 6,
  minute: 5,
  weekdays: ScheduleEntry.everyDay,
  zone: const CleaningZoneMission(
    polygon: [MapPoint(x: 1, y: 1), MapPoint(x: 4, y: 1), MapPoint(x: 4, y: 3)],
  ),
);

Future<void> _pump(WidgetTester tester, ScheduleDialogHost? host) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleTab(
            status: BleStatus.connected,
            statusAnnouncement: null,
            notice: null,
            onStatusPressed: () {},
            host: host,
          ),
        ),
      ),
    );

void main() {
  testWidgets('予定を一覧表示し、切替・削除・同期・追加が窓口へ伝わる', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      ScheduleDialogHost(
        listenable: ValueNotifier(0),
        entries: () => [_entry('a'), _entry('b')],
        canAdd: () => true,
        canSync: () => true,
        onAdd: (h, m, days) async => calls.add('add $h:$m ${days.length}'),
        onToggle: (id, on) async => calls.add('toggle $id $on'),
        onDelete: (id) async => calls.add('delete $id'),
        onSync: () async => calls.add('sync'),
      ),
    );

    expect(find.text('06:05'), findsNWidgets(2));
    expect(find.text('毎日'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('schedule-toggle-a')));
    await tester.tap(find.byKey(const Key('schedule-delete-b')));
    await tester.tap(find.byKey(const Key('schedule-sync')));
    await tester.tap(find.byKey(const Key('schedule-add')));
    await tester.pump();

    expect(calls, ['toggle a false', 'delete b', 'sync', 'add 9:0 7']);
  });

  testWidgets('範囲が無い・曜日が空・未接続のときは押せない', (tester) async {
    await _pump(
      tester,
      ScheduleDialogHost(
        listenable: ValueNotifier(0),
        entries: () => [],
        canAdd: () => false,
        canSync: () => false,
        onAdd: (h, m, days) async {},
        onToggle: (id, on) async {},
        onDelete: (id) async {},
        onSync: () async {},
      ),
    );

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
    await _pump(
      tester,
      ScheduleDialogHost(
        listenable: ValueNotifier(0),
        entries: () => [],
        canAdd: () => true,
        canSync: () => true,
        onAdd: (h, m, days) async {},
        onToggle: (id, on) async {},
        onDelete: (id) async {},
        onSync: () async {},
      ),
    );

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

  testWidgets('予定が無いときは空の案内を出す', (tester) async {
    await _pump(tester, null);
    expect(find.text('予定はまだありません'), findsOneWidget);
  });
}
