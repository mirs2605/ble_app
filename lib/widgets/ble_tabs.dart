import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_notice.dart';
import '../models/cleaning_zone.dart';
import '../models/initial_pose.dart';
import '../models/map_config.dart';
import '../models/map_edit_mode.dart';
import '../models/send_button_state.dart';
import '../services/ble_service.dart';
import '../services/map_selection_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_strings.dart';
import 'ble_status_indicator.dart';
import 'status_notification_bar.dart';
import 'floating_action_controls.dart';
import 'map_selection_area.dart';
import 'map_management_button.dart';
import 'polygon_form.dart';

class BleHomeTab extends StatelessWidget {
  final MapSelectionController mapSelection;
  final BleStatus status;
  final String? statusAnnouncement;
  final AppNotice? notice;
  final bool permissionsPermanentlyDenied;
  final ValueChanged<List<MapPoint>> onMapChanged;
  final ValueChanged<String> onLog;
  final VoidCallback onPermissionSettings;
  final VoidCallback onClearSelection;
  final VoidCallback onSend;
  final VoidCallback onStatusPressed;
  final ValueChanged<bool>? onSelectionIdleChanged;
  final bool sendCompleted;
  final bool canSend;
  final SendButtonState sendButtonState;

  /// 開始地点モード関連の配線。
  final MapEditMode editMode;
  final InitialPoseMission? initialPose;
  final ValueChanged<InitialPoseMission> onPoseChanged;
  final VoidCallback onPoseModePressed;
  final VoidCallback onClearPose;
  final VoidCallback onSendPose;
  final bool canSendPose;
  final MapConfig activeMap;
  final List<MapConfig> maps;
  final Future<void> Function(MapConfig) onMapSelected;
  final Future<void> Function(MapConfig) onMapAdded;
  final Future<void> Function(MapConfig) onMapDeleted;

  const BleHomeTab({
    super.key,
    required this.mapSelection,
    required this.status,
    required this.statusAnnouncement,
    required this.notice,
    required this.permissionsPermanentlyDenied,
    required this.onMapChanged,
    required this.onLog,
    required this.onPermissionSettings,
    required this.onClearSelection,
    required this.onSend,
    required this.onStatusPressed,
    required this.sendCompleted,
    required this.canSend,
    required this.sendButtonState,
    this.onSelectionIdleChanged,
    this.editMode = MapEditMode.polygon,
    this.initialPose,
    required this.onPoseChanged,
    required this.onPoseModePressed,
    required this.onClearPose,
    required this.onSendPose,
    required this.canSendPose,
    required this.activeMap,
    required this.maps,
    required this.onMapSelected,
    required this.onMapAdded,
    required this.onMapDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final poseMode = editMode == MapEditMode.initialPose;
    return Stack(
      fit: StackFit.expand,
      children: [
        MapSelectionArea(
          controller: mapSelection,
          mapConfig: activeMap,
          onChanged: onMapChanged,
          onLog: onLog,
          sendCompleted: sendCompleted,
          onSelectionIdleChanged: onSelectionIdleChanged,
          editMode: editMode,
          initialPose: initialPose,
          onPoseChanged: onPoseChanged,
        ),
        Positioned(
          top: 64,
          right: 12,
          child: SafeArea(
            child: MapManagementButton(
              activeMap: activeMap,
              maps: maps,
              onSelect: onMapSelected,
              onAdd: onMapAdded,
              onDelete: onMapDeleted,
            ),
          ),
        ),
        _TopLeftStatus(
          status: status,
          announcement: statusAnnouncement,
          notice: notice,
          onPressed: onStatusPressed,
          trailing: permissionsPermanentlyDenied
              ? PermissionSettingsButton(onPressed: onPermissionSettings)
              : null,
        ),
        MapSelectionActions(
          showClear: poseMode ? initialPose != null : mapSelection.hasSelection,
          showSend: poseMode ? initialPose != null : mapSelection.hasSelection,
          canSend: poseMode ? canSendPose : canSend,
          sendButtonState: sendButtonState,
          onClear: poseMode ? onClearPose : onClearSelection,
          onSend: poseMode ? onSendPose : onSend,
          clearTooltip: poseMode
              ? AppStrings.clearPoseTooltip
              : AppStrings.clearTooltip,
          showPoseMode: true,
          poseModeActive: poseMode,
          onPoseMode: onPoseModePressed,
        ),
      ],
    );
  }
}

/// 数値入力タブ。フォームのTextEditingControllerはこのWidgetが所有し、
/// 入力値のパースと地図選択からの同期もここで完結する。
/// 送信の可否・実行はController（[canSendPolygon]/[onSendPolygon]）に委ねる。
class BleValuesTab extends StatefulWidget {
  final BleStatus status;
  final String? statusAnnouncement;
  final AppNotice? notice;
  final List<MapPoint> selectedMapPoints;
  final ValueChanged<List<MapPoint>> onSendPolygon;
  final bool Function(List<MapPoint> polygon) canSendPolygon;
  final ValueChanged<InitialPoseMission> onSendInitialPose;
  final bool Function(InitialPoseMission? pose) canSendInitialPose;
  final VoidCallback onStatusPressed;
  final SendButtonState sendButtonState;

  const BleValuesTab({
    super.key,
    required this.status,
    required this.statusAnnouncement,
    required this.notice,
    required this.selectedMapPoints,
    required this.onSendPolygon,
    required this.canSendPolygon,
    required this.onSendInitialPose,
    required this.canSendInitialPose,
    required this.onStatusPressed,
    required this.sendButtonState,
  });

  @override
  State<BleValuesTab> createState() => _BleValuesTabState();
}

class _BleValuesTabState extends State<BleValuesTab> {
  static const _polygonDefaults = [
    [1.0, 1.0],
    [2.5, 1.0],
    [4.0, 2.0],
    [4.0, 3.0],
    [2.5, 3.0],
    [1.0, 2.0],
  ];

  // --- 清掃範囲フォーム ---
  late final List<TextEditingController> _xControllers;
  late final List<TextEditingController> _yControllers;

  // --- 開始地点フォーム ---
  late final TextEditingController _poseXController;
  late final TextEditingController _poseYController;
  late final TextEditingController _poseYawController;

  @override
  void initState() {
    super.initState();
    _xControllers = List.generate(
      _polygonDefaults.length,
      (i) => TextEditingController(text: _polygonDefaults[i][0].toString()),
    );
    _yControllers = List.generate(
      _polygonDefaults.length,
      (i) => TextEditingController(text: _polygonDefaults[i][1].toString()),
    );
    _poseXController = TextEditingController(text: '0.0');
    _poseYController = TextEditingController(text: '0.0');
    _poseYawController = TextEditingController(text: '0.0');

    // フォーム変更時に send ボタンの活性状態を再評価する。
    for (final c in [_poseXController, _poseYController, _poseYawController]) {
      c.addListener(_onPoseFormChanged);
    }
  }

  void _onPoseFormChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant BleValuesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 地図タブでの選択を6点フォームへ反映する。
    if (!listEquals(oldWidget.selectedMapPoints, widget.selectedMapPoints) &&
        widget.selectedMapPoints.length == _xControllers.length) {
      for (int i = 0; i < _xControllers.length; i++) {
        _xControllers[i].text = widget.selectedMapPoints[i].x.toStringAsFixed(
          2,
        );
        _yControllers[i].text = widget.selectedMapPoints[i].y.toStringAsFixed(
          2,
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [..._xControllers, ..._yControllers]) {
      c.dispose();
    }
    _poseXController.removeListener(_onPoseFormChanged);
    _poseYController.removeListener(_onPoseFormChanged);
    _poseYawController.removeListener(_onPoseFormChanged);
    _poseXController.dispose();
    _poseYController.dispose();
    _poseYawController.dispose();
    super.dispose();
  }

  /// 清掃範囲フォーム値を多角形にパースする。1つでも不正なら空リストを返す。
  List<MapPoint> _readPolygon() {
    final polygon = <MapPoint>[];
    for (int i = 0; i < _xControllers.length; i++) {
      final x = double.tryParse(_xControllers[i].text);
      final y = double.tryParse(_yControllers[i].text);
      if (x == null || y == null) return <MapPoint>[];
      polygon.add(MapPoint(x: x, y: y));
    }
    return polygon;
  }

  /// 開始地点フォーム値をパースする。不正な場合は null を返す。
  InitialPoseMission? _readInitialPose() {
    final x = double.tryParse(_poseXController.text);
    final y = double.tryParse(_poseYController.text);
    final yaw = double.tryParse(_poseYawController.text);
    if (x == null || y == null || yaw == null) return null;
    return InitialPoseMission(x: x, y: y, yaw: yaw);
  }

  @override
  Widget build(BuildContext context) {
    final polygon = _readPolygon();
    final pose = _readInitialPose();
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),

                  // ---- 開始地点セクション ----
                  const Text(
                    AppStrings.initialPoseTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _InitialPoseForm(
                    xController: _poseXController,
                    yController: _poseYController,
                    yawController: _poseYawController,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: widget.canSendInitialPose(pose)
                        ? () => widget.onSendInitialPose(pose!)
                        : null,
                    icon: const Icon(Icons.my_location),
                    label: const Text('開始地点を送信'),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),

                  // ---- 清掃範囲セクション ----
                  const Text(
                    AppStrings.cleaningAreaTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  PolygonForm(
                    xControllers: _xControllers,
                    yControllers: _yControllers,
                  ),
                  // 清掃範囲の送信はBottomSendActionのFABで行うため余白を確保。
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
        _TopLeftStatus(
          status: widget.status,
          announcement: widget.statusAnnouncement,
          notice: widget.notice,
          onPressed: widget.onStatusPressed,
        ),
        BottomSendAction(
          heroTag: 'send-values',
          enabled: widget.canSendPolygon(polygon),
          onPressed: () => widget.onSendPolygon(polygon),
          state: widget.sendButtonState,
        ),
      ],
    );
  }
}

/// 開始地点（x / y / yaw）の入力フォーム。
class _InitialPoseForm extends StatelessWidget {
  final TextEditingController xController;
  final TextEditingController yController;
  final TextEditingController yawController;

  const _InitialPoseForm({
    required this.xController,
    required this.yController,
    required this.yawController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _coordField(xController, 'X (m)')),
            const SizedBox(width: 8),
            Expanded(child: _coordField(yController, 'Y (m)')),
            const SizedBox(width: 8),
            Expanded(child: _coordField(yawController, 'Yaw (rad)')),
          ],
        ),
      ],
    );
  }

  Widget _coordField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
    );
  }
}

class BleLogsTab extends StatelessWidget {
  final List<String> logs;
  final BleStatus status;
  final String? statusAnnouncement;
  final AppNotice? notice;
  final VoidCallback onStatusPressed;

  const BleLogsTab({
    super.key,
    required this.logs,
    required this.status,
    required this.statusAnnouncement,
    required this.notice,
    required this.onStatusPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 56),
                const Text(
                  AppStrings.logsTitle,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.logBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (_, index) => Text(
                        logs[index],
                        style: const TextStyle(
                          color: AppColors.logText,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _TopLeftStatus(
          status: status,
          announcement: statusAnnouncement,
          notice: notice,
          onPressed: onStatusPressed,
        ),
      ],
    );
  }
}

class _TopLeftStatus extends StatelessWidget {
  final BleStatus status;
  final String? announcement;
  final AppNotice? notice;
  final VoidCallback? onPressed;

  /// 右端に置く追加要素（権限設定ボタンなど）。通知バーよりさらに右。
  final Widget? trailing;

  const _TopLeftStatus({
    required this.status,
    required this.announcement,
    required this.notice,
    this.onPressed,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BleStatusIndicator(
              status: status,
              announcement: announcement,
              onPressed: onPressed,
            ),
            const Spacer(),
            // Bluetoothステータスとは無関係な通知バー（右上）。
            // 文言・アイコン・色は AppNotice -> テーマ層で解決される。
            // loose指定で中身に合わせた幅になり、狭い画面でもはみ出さない。
            Flexible(
              fit: FlexFit.loose,
              child: StatusNotificationBar.notice(notice),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }
}
