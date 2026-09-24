import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_notice.dart';
import '../models/cleaning_zone.dart';
import '../models/send_button_state.dart';
import '../services/ble_service.dart';
import '../services/map_selection_controller.dart';
import '../theme/app_strings.dart';
import 'ble_status_indicator.dart';
import 'status_notification_bar.dart';
import 'floating_action_controls.dart';
import 'map_selection_area.dart';
import 'polygon_form.dart';
import '../theme/app_colors.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MapSelectionArea(
          controller: mapSelection,
          onChanged: onMapChanged,
          onLog: onLog,
          sendCompleted: sendCompleted,
          onSelectionIdleChanged: onSelectionIdleChanged,
        ),
        _TopLeftStatus(
          status: status,
          announcement: statusAnnouncement,
          notice: notice,
          onPressed: onStatusPressed,
          trailing: permissionsPermanentlyDenied
              ? PermissionSettingsButton(
                  onPressed: onPermissionSettings,
                )
              : null,
        ),
        MapSelectionActions(
          showClear: mapSelection.points.length >= 4,
          showSend: mapSelection.points.length >= 4,
          canSend: canSend,
          sendButtonState: sendButtonState,
          onClear: onClearSelection,
          onSend: onSend,
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
    required this.onStatusPressed,
    required this.sendButtonState,
  });

  @override
  State<BleValuesTab> createState() => _BleValuesTabState();
}

class _BleValuesTabState extends State<BleValuesTab> {
  static const _defaults = [
    [1.0, 1.0],
    [4.0, 1.0],
    [4.0, 3.0],
    [1.0, 3.0],
  ];

  late final List<TextEditingController> _xControllers;
  late final List<TextEditingController> _yControllers;

  @override
  void initState() {
    super.initState();
    _xControllers = List.generate(
      4,
      (i) => TextEditingController(text: _defaults[i][0].toString()),
    );
    _yControllers = List.generate(
      4,
      (i) => TextEditingController(text: _defaults[i][1].toString()),
    );
  }

  @override
  void didUpdateWidget(covariant BleValuesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 地図タブでの選択をフォームへ反映する（4点確定時のみ）。
    if (!listEquals(oldWidget.selectedMapPoints, widget.selectedMapPoints) &&
        widget.selectedMapPoints.length == 4) {
      for (int i = 0; i < 4; i++) {
        _xControllers[i].text =
            widget.selectedMapPoints[i].x.toStringAsFixed(2);
        _yControllers[i].text =
            widget.selectedMapPoints[i].y.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [..._xControllers, ..._yControllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// フォーム値を多角形にパースする。1つでも不正なら空リストを返す。
  List<MapPoint> _readPolygon() {
    final polygon = <MapPoint>[];
    for (int i = 0; i < 4; i++) {
      final x = double.tryParse(_xControllers[i].text);
      final y = double.tryParse(_yControllers[i].text);
      if (x == null || y == null) {
        return <MapPoint>[];
      }
      polygon.add(MapPoint(x: x, y: y));
    }
    return polygon;
  }

  @override
  Widget build(BuildContext context) {
    final polygon = _readPolygon();
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
                  const Text(
                    AppStrings.cleaningAreaTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  PolygonForm(
                    xControllers: _xControllers,
                    yControllers: _yControllers,
                  ),
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
                const Text(AppStrings.logsTitle,
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}
