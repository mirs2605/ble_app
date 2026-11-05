import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_notice.dart';
import '../models/cleaning_zone.dart';
import '../models/map_config.dart';
import '../models/map_geometry.dart';
import '../models/map_receive_host.dart';
import '../models/schedule_dialog_host.dart';
import '../models/schedule_entry.dart';
import '../models/shape_template.dart';
import '../models/send_button_state.dart';
import '../services/ble_connection.dart';
import '../services/ble_service.dart';
import '../services/map_config_repository.dart';
import '../services/map_image_storage.dart';
import '../services/map_selection_controller.dart';
import '../services/permission_gateway.dart';
import '../services/schedule_repository.dart';
import '../theme/app_strings.dart';
import 'map_catalog.dart';
import 'notice_board.dart';
import 'robot_map_receiver.dart';
import 'schedule_coordinator.dart';
import 'send_mission_tracker.dart';

/// 画面の協調役（facade）。BLE接続・権限・送信進行・時限表示・予定同期の
/// 詳細は [BleConnection] / [PermissionGateway] / [SendMissionTracker] /
/// [NoticeBoard] / [ScheduleCoordinator] に委ね、このクラスは配線と公開状態に徹する。
class BleHomeController extends ChangeNotifier {
  BleHomeController({
    BleConnectionFactory? connectionFactory,
    PermissionGateway? permissionGateway,
    MapConfigRepository? mapRepository,
    ScheduleRepository? scheduleRepository,
    ScheduleCoordinator? scheduleCoordinator,
    RobotMapReceiver? robotMapReceiver,
    MapImageStorage Function()? mapImageStorageFactory,
  }) : _permissions = permissionGateway ?? const DefaultPermissionGateway(),
       _catalog = MapCatalog(
         repository: mapRepository ?? MapConfigRepository.instance,
       ),
       _mapImageStorageFactory = mapImageStorageFactory ?? MapImageStorage.new {
    _robotMapReceiver = robotMapReceiver;
    _connection = (connectionFactory ?? BleService.new)(
      onLog: _addServiceLog,
      onStatusChanged: _handleStatusChanged,
    );
    if (scheduleCoordinator != null) {
      _scheduleCoordinator = scheduleCoordinator;
    } else if (scheduleRepository != null) {
      _scheduleCoordinator = ScheduleCoordinator(
        repository: scheduleRepository,
        connection: _connection,
        selectedPolygon: () => mapSelection.points,
        isConnected: () => _status == BleStatus.connected,
        onLog: addLog,
        onNotice: notifyNotice,
      );
    } else {
      _scheduleCoordinator = null;
    }
    _scheduleCoordinator?.addListener(_guardedNotify);
    _catalog.addListener(_guardedNotify);
    _statusBoard = NoticeBoard<String>(onChanged: _guardedNotify);
    _noticeBoard = NoticeBoard<AppNotice>(onChanged: _guardedNotify);
    unawaited(_startAutoConnect());
    unawaited(_loadMapConfig());
  }

  late final BleConnection _connection;
  final PermissionGateway _permissions;
  final MapCatalog _catalog;
  final MapImageStorage Function() _mapImageStorageFactory;
  late final ScheduleCoordinator? _scheduleCoordinator;
  RobotMapReceiver? _robotMapReceiver;

  /// 接続が確立している間 true。接続の確立直後に一度だけ同期するための印。
  bool _linkUp = false;

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

  /// 現在アクティブなマップ設定。
  MapConfig get activeMapConfig => _catalog.active;

  /// 登録済みマップ一覧。
  List<MapConfig> get allMaps => _catalog.all;

  /// 表示中の独立通知。一時通知（3秒）を優先し、なければ囲み促進のヒント。
  /// ヒント条件は従来の画面下表示と同一：未選択かつ描画中でないこと。
  AppNotice? get activeNotice {
    final hint = _selectionIdle && mapSelection.points.isEmpty
        ? AppNotice.encloseRange
        : null;
    return _noticeBoard.value ?? hint;
  }

  bool get sendCompleted => _sendTracker.sendCompleted;
  SendButtonState get sendButtonState => _sendTracker.buttonState;
  List<String> get logs => List.unmodifiable(_logs);
  List<MapPoint> get selectedMapPoints =>
      List<MapPoint>.unmodifiable(mapSelection.points);
  bool get canSendSelectedMap => canSendPolygon(mapSelection.points);

  void _guardedNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _loadMapConfig() => _catalog.load();

  /// アクティブマップを切り替える。
  Future<void> switchMap(MapConfig config) async {
    if (!await _catalog.switchTo(config) || _isDisposed) return;
    // マップ切り替え時は選択をリセットする。
    clearSelection();
  }

  /// マップを追加してアクティブにする。
  Future<void> addMap(MapConfig config) async {
    if (!await _catalog.add(config) || _isDisposed) return;
    clearSelection();
  }

  /// マップを削除する。アクティブマップは削除不可。
  Future<void> deleteMap(MapConfig config) async {
    final error = await _catalog.delete(config);
    if (error != null) addLog('❌ $error');
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

  /// フリーハンド選択の頂点数を変更する。既存の選択は点数が合わなくなるため消す。
  void setVertexCount(int count) {
    final next = count.clamp(
      MapGeometry.minFreehandVertexCount,
      MapGeometry.maxFreehandVertexCount,
    );
    if (next == mapSelection.vertexCount) return;
    mapSelection.vertexCount = next;
    clearSelection();
  }

  /// ひな形の形を選択範囲として地図中央に置く。頂点数もひな形に合わせる。
  void applyShapeTemplate(ShapeTemplate template) {
    mapSelection.vertexCount = template.vertexCount;
    setSelectedMapPoints(template.placeOn(_catalog.active));
    addLog('⭐ 「${template.label}」のひな形を配置しました');
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

  // ─────────────────────────────────────────
  // 定時清掃の予定（ScheduleCoordinator へ委譲）
  // ─────────────────────────────────────────

  /// 予定機能が使えるか（初期化時にリポジトリまたはコーディネータが渡されている）。
  bool get scheduleAvailable => _scheduleCoordinator != null;

  /// ダイアログ表示用のホスト窓口。
  ScheduleDialogHost? get scheduleDialogHost =>
      _scheduleCoordinator?.createDialogHost();

  /// 画面に出す予定（削除済みを除く）。
  List<ScheduleEntry> get schedules =>
      _scheduleCoordinator?.schedules ?? const [];

  /// 選択中の範囲で予定を追加できるか。
  bool get canAddSchedule => _scheduleCoordinator?.canAdd ?? false;

  /// 予定同期が可能か（接続中）。
  bool get canSyncSchedules => _scheduleCoordinator?.canSync ?? false;

  /// 選択中の範囲を予定として追加する。
  Future<void> addSchedule({
    required int hour,
    required int minute,
    required Set<int> weekdays,
  }) =>
      _scheduleCoordinator?.addSchedule(
        hour: hour,
        minute: minute,
        weekdays: weekdays,
      ) ??
      Future.value();

  /// 予定の有効/無効を切り替える。
  Future<void> setScheduleEnabled(String id, bool enabled) =>
      _scheduleCoordinator?.setScheduleEnabled(id, enabled) ?? Future.value();

  /// 予定を削除する（墓標化）。
  Future<void> deleteSchedule(String id) =>
      _scheduleCoordinator?.deleteSchedule(id) ?? Future.value();

  /// ロボットと予定を突き合わせる。
  Future<void> syncSchedules({bool announce = true}) =>
      _scheduleCoordinator?.syncSchedules(announce: announce) ?? Future.value();

  // ─────────────────────────────────────────
  // ロボットの地図の受信（RobotMapReceiver へ委譲）
  // ─────────────────────────────────────────

  RobotMapReceiver get _mapReceiver => _robotMapReceiver ??= () {
    final storage = _mapImageStorageFactory();
    final receiver = RobotMapReceiver(
      connection: _connection,
      saveImage: storage.saveBytes,
      deleteImage: storage.delete,
      addMap: addMap,
      isConnected: () => _status == BleStatus.connected,
      onLog: addLog,
    );
    return receiver;
  }();

  /// 地図管理ダイアログに渡す、ロボットの地図を受信するための窓口。
  MapReceiveHost get mapReceiveHost {
    final receiver = _mapReceiver;
    return MapReceiveHost(
      listenable: Listenable.merge([receiver, this]),
      canReceive: () => receiver.canReceive,
      progress: () => receiver.busy ? receiver.progress : null,
      onReceive: receiver.receive,
    );
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
    final up = status == BleStatus.connected || status == BleStatus.sending;
    final becameUp = up && !_linkUp;
    _linkUp = up;
    if (becameUp) {
      // _status の更新後に走らせる（同期は接続済みを前提にする）。
      _scheduleCoordinator?.onLinkEstablished();
    }
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

  void _addServiceLog(String message) {
    if (_isDisposed) return;
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
    _scheduleCoordinator?.dispose();
    _robotMapReceiver?.dispose();
    _catalog.dispose();
    _statusBoard.dispose();
    _noticeBoard.dispose();
    super.dispose();
  }
}
