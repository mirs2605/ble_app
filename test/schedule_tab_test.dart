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
  testWidgets('予定を一覧表示し、切替・削除・同期が窓口へ伝わる', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      ScheduleDialogHost(
        listenable: ValueNotifier(0),
        entries: () => [_entry('a'), _entry('b')],
        canAdd: () => true,
        canSync: () => true,
        onAdd: (h, m, d) async {},
        onToggle: (id, on) async => calls.add('toggle $id $on'),
        onDelete: (id) async => calls.add('delete $id'),
        onSync: () async => calls.add('sync'),
      ),
    );

    expect(find.text('06:05'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('schedule-toggle-a')));
    await tester.tap(find.byKey(const Key('schedule-delete-b')));
    await tester.tap(find.byKey(const Key('schedule-sync')));
    await tester.pump();

    expect(calls, ['toggle a false', 'delete b', 'sync']);
  });

  testWidgets('予定が無いときは空の案内を出す', (tester) async {
    await _pump(tester, null);
    expect(find.text('予定はまだありません'), findsOneWidget);
  });
}
