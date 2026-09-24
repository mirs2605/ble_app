import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/controllers/ble_home_controller.dart';
import 'package:mirs_ble_app/models/app_notice.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/send_button_state.dart';
import 'package:mirs_ble_app/services/ble_connection.dart';
import 'package:mirs_ble_app/services/permission_gateway.dart';
import 'package:mirs_ble_app/services/permission_service.dart';

class FakeBleConnection implements BleConnection {
  FakeBleConnection({required this.onLog, required this.onStatusChanged});

  void Function(String message) onLog;
  void Function(BleStatus status) onStatusChanged;

  @override
  BleStatus status = BleStatus.connected;

  int startAutoCalls = 0;
  int scanCalls = 0;
  int sendCalls = 0;
  int disposeCalls = 0;
  bool sendResult = true;

  @override
  void startAutoConnect() => startAutoCalls++;

  @override
  void stopAutoConnect() {}

  @override
  Future<void> scanAndConnect() async {
    scanCalls++;
  }

  @override
  Future<bool> sendCleaningZone(CleaningZoneMission zone) async {
    sendCalls++;
    return sendResult;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  void emit(BleStatus next) {
    status = next;
    onStatusChanged(next);
  }
}

class FakePermissions implements PermissionGateway {
  FakePermissions.granted()
    : granted = true,
      permanentlyDenied = false,
      deniedNames = const [];

  FakePermissions.denied()
    : granted = false,
      permanentlyDenied = true,
      deniedNames = const ['Permission.bluetoothScan'];

  final bool granted;
  final bool permanentlyDenied;
  final List<String> deniedNames;
  bool settingsResult = true;

  @override
  Future<PermissionRequestResult> requestBlePermissions() async {
    return PermissionRequestResult(
      isGranted: granted,
      permanentlyDenied: permanentlyDenied,
      deniedNames: deniedNames,
    );
  }

  @override
  Future<bool> openSettings() async => settingsResult;
}

BleHomeController buildController({
  FakeBleConnection? connection,
  FakePermissions? permissions,
}) {
  final conn = connection ?? FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
  final perms = permissions ?? FakePermissions.granted();
  return BleHomeController(
    connectionFactory: ({required onLog, required onStatusChanged}) {
      conn.onLog = onLog;
      conn.onStatusChanged = onStatusChanged;
      return conn;
    },
    permissionGateway: perms,
  );
}

/// コンストラクタ内の非同期自動接続を流す。
Future<void> flushAsync() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('権限許可で自動接続が開始される', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);

    await flushAsync();
    expect(conn.startAutoCalls, 1);
    expect(conn.scanCalls, 1);
    expect(controller.activeNotice, AppNotice.autoConnectStarted);
  });

  test('権限拒否でスキャンせず通知する', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(
      connection: conn,
      permissions: FakePermissions.denied(),
    );
    addTearDown(controller.dispose);

    await flushAsync();
    expect(controller.permissionsPermanentlyDenied, isTrue);
    expect(conn.scanCalls, 0);
    expect(controller.activeNotice, AppNotice.permissionMissing);
  });

  test('空の範囲では送信せず通知する', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);
    await flushAsync();

    // 初期選択は空。フォーム代替は数値タブ側の責務。
    await controller.sendPressed();

    expect(conn.sendCalls, 0);
    expect(controller.activeNotice, AppNotice.specifyRange);
    expect(controller.sendCompleted, isFalse);
  });

  test('不正な範囲では送信せず通知する', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);
    await flushAsync();

    await controller.sendPolygon(const [
      MapPoint(x: 0, y: 0),
      MapPoint(x: double.nan, y: 1),
      MapPoint(x: 1, y: 1),
    ]);

    expect(conn.sendCalls, 0);
    expect(controller.activeNotice, AppNotice.invalidRange);
  });

  test('送信成功で完了状態になり通知バーは出ない', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);
    await flushAsync();
    controller.clearNotification();

    controller.setSelectedMapPoints(const [
      MapPoint(x: 1, y: 1),
      MapPoint(x: 4, y: 1),
      MapPoint(x: 4, y: 3),
      MapPoint(x: 1, y: 3),
    ]);
    await controller.sendPressed();

    expect(conn.sendCalls, 1);
    expect(controller.sendCompleted, isTrue);
    expect(controller.sendButtonState, SendButtonState.completed);
    // 送信完了の文言表示は通知バーに任せる。
    expect(controller.activeNotice, AppNotice.sendDone);
  });

  test('送信失敗で完了にならず失敗通知になる', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {})
      ..sendResult = false;
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);
    await flushAsync();

    controller.setSelectedMapPoints(const [
      MapPoint(x: 1, y: 1),
      MapPoint(x: 4, y: 1),
      MapPoint(x: 4, y: 3),
      MapPoint(x: 1, y: 3),
    ]);
    await controller.sendPressed();

    expect(controller.sendCompleted, isFalse);
    expect(controller.sendButtonState, SendButtonState.ready);
    expect(controller.activeNotice, AppNotice.sendFailed);
  });

  test('sendingはBT表示に反映されない', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);
    await flushAsync();

    conn.emit(BleStatus.sending);

    expect(controller.status, BleStatus.sending);
    expect(controller.statusAnnouncement, isNull);
    expect(controller.sendButtonState, SendButtonState.sending);
  });

  test('状態変化でラベル表示される', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);
    await flushAsync();

    conn.emit(BleStatus.scanning);

    expect(controller.status, BleStatus.scanning);
    expect(controller.statusAnnouncement, '検索中');
  });

  test('設定オープン失敗で通知する', () async {
    final permissions = FakePermissions.granted()..settingsResult = false;
    final controller = buildController(permissions: permissions);
    addTearDown(controller.dispose);
    await flushAsync();

    await controller.openPermissionSettings();

    expect(controller.activeNotice, AppNotice.settingsOpenFailed);
  });

  test('選択変更で送信進行がリセットされる', () async {
    final conn = FakeBleConnection(onLog: (_) {}, onStatusChanged: (_) {});
    final controller = buildController(connection: conn);
    addTearDown(controller.dispose);
    await flushAsync();

    controller.setSelectedMapPoints(const [
      MapPoint(x: 1, y: 1),
      MapPoint(x: 4, y: 1),
      MapPoint(x: 4, y: 3),
      MapPoint(x: 1, y: 3),
    ]);
    await controller.sendPressed();
    expect(controller.sendCompleted, isTrue);

    controller.setSelectedMapPoints(const [
      MapPoint(x: 2, y: 2),
      MapPoint(x: 5, y: 2),
      MapPoint(x: 5, y: 4),
      MapPoint(x: 2, y: 4),
    ]);
    expect(controller.sendCompleted, isFalse);
    expect(controller.sendButtonState, SendButtonState.ready);
  });

  test('選択状態は共有インスタンスが唯一の所有者である', () async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await flushAsync();

    const points = [
      MapPoint(x: 2, y: 2),
      MapPoint(x: 5, y: 2),
      MapPoint(x: 5, y: 4),
      MapPoint(x: 2, y: 4),
    ];
    controller.setSelectedMapPoints(points);

    // ControllerとWidgetが同じインスタンスを見る。
    expect(controller.mapSelection.points, points);
    expect(controller.selectedMapPoints, points);

    // 描画中の途中状態も含めてクリアされる。
    controller.mapSelection.selectionStart = const Offset(1, 1);
    controller.clearSelection();
    expect(controller.mapSelection.points, isEmpty);
    expect(controller.mapSelection.selectionStart, isNull);
    expect(controller.selectedMapPoints, isEmpty);
  });

  test('初期状態で囲み促進ヒントが出る', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    // 自動接続の非同期処理より前に評価：一時通知なし→ヒント表示。
    expect(controller.activeNotice, AppNotice.encloseRange);
  });

  test('描画中はヒントが隠れ終了で戻る', () async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await flushAsync();
    controller.clearNotification();

    controller.setSelectionIdle(false);
    expect(controller.activeNotice, isNull);

    controller.setSelectionIdle(true);
    expect(controller.activeNotice, AppNotice.encloseRange);
  });

  test('選択確定後はヒントが出ない', () async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await flushAsync();
    controller.clearNotification();

    controller.setSelectedMapPoints(const [
      MapPoint(x: 1, y: 1),
      MapPoint(x: 4, y: 1),
      MapPoint(x: 4, y: 3),
      MapPoint(x: 1, y: 3),
    ]);
    expect(controller.activeNotice, isNull);
  });

  test('一時通知がヒントより優先され消去後に復帰する', () async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await flushAsync();
    controller.clearNotification();
    expect(controller.activeNotice, AppNotice.encloseRange);

    controller.notifyNotice(AppNotice.sendFailed);
    expect(controller.activeNotice, AppNotice.sendFailed);

    controller.clearNotification();
    expect(controller.activeNotice, AppNotice.encloseRange);
  });
}
