import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_notice.dart';
import '../models/cleaning_zone.dart';
import '../models/send_button_state.dart';
import '../services/ble_connection.dart';
import '../services/ble_service.dart';
import '../services/map_selection_controller.dart';
import '../services/permission_gateway.dart';
import '../theme/app_strings.dart';
import 'notice_board.dart';
import 'send_mission_tracker.dart';

/// 画面の協調役（facade）。BLE接続・権限・送信進行・時限表示の
/// 詳細は [BleConnection] / [PermissionGateway] / [SendMissionTracker] /
/// [NoticeBoard] に委ね、このクラスは配線と公開状態に徹する。
class BleHomeController extends ChangeNotifier {
  BleHomeController({
    BleConnectionFactory? connectionFactory,
    PermissionGateway? permissionGateway,
  }) : _permissions = permissionGateway ?? const DefaultPermissionGateway() {
    _connection =
        (connectionFactory ?? BleService.new)(
          onLog: _addServiceLog,
          onStatusChanged: _handleStatusChanged,
        );
    _statusBoard = NoticeBoard<String>(onChanged: _guardedNotify);
    _noticeBoard = NoticeBoard<AppNotice>(onChanged: _guardedNotify);
    unawaited(_startAutoConnect());
  }

  late final BleConnection _connection;
  final PermissionGateway _permissions;

  BleStatus _status = BleStatus.idle;
  bool _permissionsPermanentlyDenied = false;
  late final NoticeBoard<String> _statusBoard;
  late final NoticeBoard<AppNotice> _noticeBoard;
  final SendMissionTracker _sendTracker = SendMissionTracker();

  /// 地図選択の唯一の所有者。MapSelectionAreaはこのインスタンスを
  /// 直接操作し、確定時にonChangedで通知する（値のミラーは持たない）。
  final MapSelectionController mapSelection = MapSelectionController();

  /// フリーハンド描画中でないこと。MapSelectionAreaが報告する。
  /// ヒント表示条件（未選択かつ描画中でない）の後半を担う。
  bool _selectionIdle = true;
  final List<String> _logs = [];
  int selectedTabIndex = 1;
  bool _isDisposed = false;
  bool _autoConnectStarted = false;

  BleStatus get status => _status;
  bool get permissionsPermanentlyDenied => _permissionsPermanentlyDenied;
  String? get statusAnnouncement => _statusBoard.value;

  /// 表示中の独立通知。一時通知（3秒）を優先し、なければ囲み促進ヒント。
  /// ヒント条件は従来の画面下表示と同一：未選択かつ描画中でないこと。
  AppNotice? get activeNotice =>
      _noticeBoard.value ??
      (_selectionIdle && mapSelection.points.isEmpty
          ? AppNotice.encloseRange
          : null);

  bool get sendCompleted => _sendTracker.sendCompleted;
  SendButtonState get sendButtonState => _sendTracker.buttonState;
  List<String> get logs => List.unmodifiable(_logs);
  List<MapPoint> get selectedMapPoints =>
      List<MapPoint>.unmodifiable(mapSelection.points);
  bool get canSendSelectedMap => canSendPolygon(mapSelection.points);

  void _guardedNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void selectTab(int index) {
    if (_isDisposed) return;
    selectedTabIndex = index;
    _guardedNotify();
  }

  void setSelectedMapPoints(List<MapPoint> points) {
    mapSelection.points = List<MapPoint>.from(points);
    _sendTracker.resetProgress();
    notifyListeners();
  }

  void clearSelection() {
    mapSelection.clear();
    _sendTracker.resetProgress();
    notifyListeners();
  }

  /// MapSelectionAreaからの描画状態報告を受け取る。
  void setSelectionIdle(bool idle) {
    if (_isDisposed || _selectionIdle == idle) return;
    _selectionIdle = idle;
    notifyListeners();
  }

  void showStatusAnnouncement() {
    _statusBoard.show(AppStrings.bleStatusLabel(_status));
  }

  /// Bluetoothステータスとは無関係な独立通知を表示する。
  /// 文言・アイコン・色は [AppNotice] からテーマ層が解決する。
  /// [duration] 経過後に上端へスライドして自動で非表示になる。
  void notifyNotice(
    AppNotice notice, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (_isDisposed) return;
    _noticeBoard.show(notice, duration: duration);
  }

  void clearNotification() {
    _noticeBoard.clear();
  }

  void addLog(String message) {
    if (_isDisposed) return;
    _addLog(message);
  }

  /// 地図タブ用。選択中の範囲を送信する。
  Future<void> sendPressed() =>
      sendPolygon(List<MapPoint>.from(mapSelection.points));

  /// 任意の多角形を送信する。数値タブはフォーム値をパースして渡す。
  /// 空・不正な入力は送信せず、対応する通知を出す。
  Future<void> sendPolygon(List<MapPoint> polygon) async {
    if (polygon.isEmpty) {
      addLog('❌ ${AppStrings.specifyRange}');
      notifyNotice(AppNotice.specifyRange);
      return;
    }

    final zone = CleaningZoneMission(polygon: polygon);
    if (!zone.isValid) {
      addLog('❌ ${AppStrings.invalidRange}');
      notifyNotice(AppNotice.invalidRange);
      return;
    }

    _sendTracker.beginSend();
    notifyListeners();
    final sent = await _connection.sendCleaningZone(zone);
    if (_isDisposed) return;
    if (sent) {
      _sendTracker.succeed(List<MapPoint>.from(polygon));
      // 送信完了の文言表示は通知バーに任せる。
      notifyNotice(AppNotice.sendDone);
    } else {
      _sendTracker.failSend();
      notifyNotice(AppNotice.sendFailed);
    }
    notifyListeners();
  }

  /// 送信ボタン活性条件。数値タブはフォーム値で判定する。
  bool canSendPolygon(List<MapPoint> polygon) =>
      _status == BleStatus.connected && _sendTracker.canSend(polygon);

  Future<void> openPermissionSettings() async {
    final opened = await _permissions.openSettings();
    if (!opened) {
      addLog('❌ ${AppStrings.settingsOpenFailed}');
      notifyNotice(AppNotice.settingsOpenFailed);
    }
  }

  Future<void> _startAutoConnect() async {
    if (_autoConnectStarted || _isDisposed) return;
    _autoConnectStarted = true;
    if (!await _requestPermissions() || _isDisposed) return;
    _connection.startAutoConnect();
    addLog(AppStrings.autoConnectGuide);
    notifyNotice(AppNotice.autoConnectStarted);
    unawaited(_connection.scanAndConnect());
  }

  Future<bool> _requestPermissions() async {
    final result = await _permissions.requestBlePermissions();
    if (_isDisposed) return false;
    _permissionsPermanentlyDenied = result.permanentlyDenied;
    notifyListeners();
    if (!result.isGranted) {
      addLog(AppStrings.permissionMissingDetails(result.deniedNames));
      notifyNotice(AppNotice.permissionMissing);
      return false;
    }
    return true;
  }

  void _handleStatusChanged(BleStatus status) {
    if (_isDisposed) return;
    // 送信中はBTアイコンを反応させない。送信表示は送信ボタンと
    // 独立通知バー側に任せ、接続表示は維持する。
    // BLE層内部の status は sending になるため自動再スキャン抑止は効く。
    if (status == BleStatus.sending) {
      _status = status;
      _sendTracker.markSending();
      notifyListeners();
      return;
    }
    _sendTracker.isSending = false;
    // 送信成功後の connected -> connected など、状態が変わっていない場合は
    // 「接続済み」を再表示しない（送信のたびにアイコンが膨らむのを防ぐ）。
    if (status == _status) {
      notifyListeners();
      return;
    }
    _status = status;
    _statusBoard.show(AppStrings.bleStatusLabel(status));
  }

  void _addServiceLog(String message) {    if (_isDisposed) return;
    _addLog(message, trim: true);
  }

  void _addLog(String message, {bool trim = false}) {
    if (_isDisposed) return;
    final now = DateTime.now();
    final timestamp =
        '[${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}]';
    _logs.insert(0, '$timestamp $message');
    if (trim && _logs.length > 100) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connection.stopAutoConnect();
    unawaited(_connection.dispose());
    _statusBoard.dispose();
    _noticeBoard.dispose();
    super.dispose();
  }
}
