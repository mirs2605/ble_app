import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cleaning_zone.dart';
import '../models/send_button_state.dart';
import '../services/ble_service.dart';
import '../services/permission_service.dart';

class BleHomeController extends ChangeNotifier {
  late final BleService bleService;

  BleStatus _status = BleStatus.idle;
  bool _permissionsPermanentlyDenied = false;
  String? _statusAnnouncement;
  IconData? _announcementIcon;
  Timer? _announcementTimer;
  String? _sendAnnouncement;
  Timer? _sendAnnouncementTimer;
  bool _sendCompleted = false;
  final List<String> _logs = [];
  final List<TextEditingController> xControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> yControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  List<MapPoint> _selectedMapPoints = [];
  List<MapPoint>? _lastSentMapPoints;
  int selectedTabIndex = 1;
  bool _isDisposed = false;

  BleHomeController() {
    bleService = BleService(
      onLog: _addServiceLog,
      onStatusChanged: _handleStatusChanged,
    );
    _setDefaultValues();
    unawaited(_startAutoConnect());
  }

  BleStatus get status => _status;
  bool get permissionsPermanentlyDenied => _permissionsPermanentlyDenied;
  String? get statusAnnouncement => _statusAnnouncement;
  IconData? get announcementIcon => _announcementIcon;
  String? get sendAnnouncement => _sendAnnouncement;
  bool get sendCompleted => _sendCompleted;
  SendButtonState get sendButtonState {
    if (_sendCompleted) return SendButtonState.completed;
    if (_sendAnnouncement == '送信中') return SendButtonState.sending;
    return SendButtonState.ready;
  }
  List<String> get logs => List.unmodifiable(_logs);
  List<MapPoint> get selectedMapPoints => List.unmodifiable(_selectedMapPoints);
  bool get canSendSelectedMap =>
      _status == BleStatus.connected &&
      _selectedMapPoints.length >= 4 &&
      !_samePoints(_selectedMapPoints, _lastSentMapPoints);

  void selectTab(int index) {
    selectedTabIndex = index;
    notifyListeners();
  }

  void setSelectedMapPoints(List<MapPoint> points) {
    _selectedMapPoints = List<MapPoint>.from(points);
    _sendCompleted = false;
    _clearSendAnnouncement();
    _syncFormFromSelection();
    notifyListeners();
  }

  void clearSelection() {
    _selectedMapPoints = [];
    _sendCompleted = false;
    _clearSendAnnouncement();
    notifyListeners();
  }

  void showStatusAnnouncement() {
    _showAnnouncement(_statusLabel(_status), null);
  }

  void addLog(String message) {
    if (_isDisposed) return;
    _addLog(message);
  }

  Future<void> sendPressed() async {
    final polygon = _selectedMapPoints.isNotEmpty
        ? List<MapPoint>.from(_selectedMapPoints)
        : _readFormPolygon();

    if (polygon.isEmpty) {
      addLog('❌ 範囲を指定してください');
      return;
    }

    final zone = CleaningZoneMission(polygon: polygon);
    if (!zone.isValid) {
      addLog('❌ 清掃範囲が不正です');
      return;
    }

    _showSendAnnouncement('送信中');
    _sendCompleted = false;
    final sent = await bleService.sendCleaningZone(zone);
    if (sent && !_isDisposed) {
      _lastSentMapPoints = List<MapPoint>.from(polygon);
      _sendCompleted = true;
      _showSendAnnouncement('送信完了');
    } else if (!_isDisposed) {
      _clearSendAnnouncement();
    }

  }

  bool _samePoints(List<MapPoint> points, List<MapPoint>? other) {
    if (other == null || points.length != other.length) return false;
    for (var i = 0; i < points.length; i++) {
      if (points[i] != other[i]) return false;
    }
    return true;
  }

  Future<void> openPermissionSettings() async {
    final opened = await PermissionService.openSettings();
    if (!opened) {
      addLog('❌ アプリ設定を開けませんでした');
    }
  }

  void _setDefaultValues() {
    final defaults = [
      [1.0, 1.0],
      [4.0, 1.0],
      [4.0, 3.0],
      [1.0, 3.0],
    ];
    for (int i = 0; i < 4; i++) {
      xControllers[i].text = defaults[i][0].toString();
      yControllers[i].text = defaults[i][1].toString();
    }
  }

  Future<void> _startAutoConnect() async {
    if (!await _requestPermissions() || _isDisposed) return;
    bleService.startAutoConnect();
    addLog('📡 BLE サーバーに近づくと自動で接続します');
    unawaited(bleService.scanAndConnect());
  }

  Future<bool> _requestPermissions() async {
    final result = await PermissionService.requestBlePermissions();
    if (_isDisposed) return false;
    _permissionsPermanentlyDenied = result.permanentlyDenied;
    notifyListeners();
    if (!result.isGranted) {
      addLog('❌ パーミッション不足: ${result.deniedNames.join(', ')}');
      return false;
    }
    return true;
  }

  void _handleStatusChanged(BleStatus status) {
    if (_isDisposed) return;
    _announcementTimer?.cancel();
    _status = status;
    if (status == BleStatus.sending) {
      _showSendAnnouncement('送信中');
    }
    _statusAnnouncement = status == BleStatus.sending
        ? null
        : _statusLabel(status);
    _announcementIcon = null;
    notifyListeners();
    _announcementTimer = Timer(const Duration(seconds: 3), () {
      if (_isDisposed) return;
      _statusAnnouncement = null;
      notifyListeners();
    });
  }

  void _showAnnouncement(String message, IconData? icon) {
    _announcementTimer?.cancel();
    _statusAnnouncement = message;
    _announcementIcon = icon;
    notifyListeners();
    _announcementTimer = Timer(const Duration(seconds: 3), () {
      if (_isDisposed) return;
      _statusAnnouncement = null;
      _announcementIcon = null;
      notifyListeners();
    });
  }

  void _showSendAnnouncement(String message) {
    _sendAnnouncementTimer?.cancel();
    _sendAnnouncement = message;
    notifyListeners();
    if (message == '送信完了') return;
    _sendAnnouncementTimer = Timer(const Duration(seconds: 3), () {
      if (_isDisposed) return;
      _sendAnnouncement = null;
      notifyListeners();
    });
  }

  void _clearSendAnnouncement() {
    _sendAnnouncementTimer?.cancel();
    _sendAnnouncement = null;
    notifyListeners();
  }

  List<MapPoint> _readFormPolygon() {
    final polygon = <MapPoint>[];
    for (int i = 0; i < 4; i++) {
      final x = double.tryParse(xControllers[i].text);
      final y = double.tryParse(yControllers[i].text);
      if (x == null || y == null) {
        return <MapPoint>[];
      }
      polygon.add(MapPoint(x: x, y: y));
    }
    return polygon;
  }

  void _syncFormFromSelection() {
    if (_selectedMapPoints.length != 4) return;
    for (int i = 0; i < 4; i++) {
      xControllers[i].text = _selectedMapPoints[i].x.toStringAsFixed(2);
      yControllers[i].text = _selectedMapPoints[i].y.toStringAsFixed(2);
    }
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

  String _statusLabel(BleStatus status) => switch (status) {
    BleStatus.idle => '未接続',
    BleStatus.scanning => '検索中',
    BleStatus.connecting => '接続中',
    BleStatus.connected => '接続済み',
    BleStatus.sending => '接続済み',
    BleStatus.disconnected => '切断',
    BleStatus.error => 'エラー',
  };

  @override
  void dispose() {
    _isDisposed = true;
    bleService.stopAutoConnect();
    unawaited(bleService.dispose());
    _announcementTimer?.cancel();
    _sendAnnouncementTimer?.cancel();
    for (final controller in xControllers) {
      controller.dispose();
    }
    for (final controller in yControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
