import 'package:flutter/material.dart';

import '../models/app_notice.dart';
import '../models/cleaning_zone.dart';
import '../models/map_config.dart';
import '../models/map_geometry.dart';
import '../models/send_button_state.dart';
import '../models/shape_template.dart';
import '../services/ble_connection.dart';
import '../services/map_selection_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_strings.dart';
import 'ble_status_indicator.dart';
import 'status_notification_bar.dart';
import 'floating_action_controls.dart';
import 'map_selection_area.dart';
import 'map_management_button.dart';
import 'schedule_dialog.dart';

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

  /// 点数スライダーの変更通知。null ならスライダーを出さない。
  final ValueChanged<int>? onVertexCountChanged;

  /// ひな形（星など）の選択通知。null ならひな形ボタンを出さない。
  final ValueChanged<ShapeTemplate>? onShapeTemplateSelected;

  final MapConfig activeMap;

  /// 定時清掃ダイアログの窓口。null なら定時清掃ボタンを出さない。
  final ScheduleDialogHost? scheduleHost;

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
    this.onVertexCountChanged,
    this.onShapeTemplateSelected,
    required this.activeMap,
    this.scheduleHost,
  });

  @override
  Widget build(BuildContext context) {
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
          showClear: mapSelection.hasSelection,
          showSend: mapSelection.hasSelection,
          canSend: canSend,
          sendButtonState: sendButtonState,
          onClear: onClearSelection,
          onSend: onSend,
          onSchedule: scheduleHost == null
              ? null
              : () => showScheduleDialog(context, scheduleHost!),
          extraAction: onShapeTemplateSelected == null
              ? null
              : ShapeTemplateButton(onSelected: onShapeTemplateSelected!),
        ),
        if (onVertexCountChanged != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 88,
            child: VertexCountSlider(
              value: mapSelection.vertexCount,
              onChanged: onVertexCountChanged!,
            ),
          ),
      ],
    );
  }
}

/// 星などのひな形を選ぶボタン。選ぶと地図中央に範囲が置かれる。
class ShapeTemplateButton extends StatelessWidget {
  final ValueChanged<ShapeTemplate> onSelected;

  const ShapeTemplateButton({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ShapeTemplate>(
      tooltip: 'ひな形',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final template in ShapeTemplate.all)
          PopupMenuItem<ShapeTemplate>(
            value: template,
            child: Text('${template.label}（${template.vertexCount}点）'),
          ),
      ],
      child: const CircleAvatar(
        radius: 28,
        backgroundColor: Colors.black54,
        child: Icon(Icons.star_outline, color: Colors.white),
      ),
    );
  }
}

/// 清掃範囲の点数を選ぶスライダー。
class VertexCountSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const VertexCountSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const min = MapGeometry.minFreehandVertexCount;
    const max = MapGeometry.maxFreehandVertexCount;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text('点数 $value', style: const TextStyle(color: Colors.white)),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                label: '$value',
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 地図タブ。地図の切替・追加・削除・ロボットからの受信を行う。
class MapSwitchTab extends StatelessWidget {
  final BleStatus status;
  final String? statusAnnouncement;
  final AppNotice? notice;
  final VoidCallback onStatusPressed;
  final MapConfig activeMap;
  final List<MapConfig> maps;
  final Future<void> Function(MapConfig) onMapSelected;
  final Future<void> Function(MapConfig) onMapAdded;
  final Future<void> Function(MapConfig) onMapDeleted;

  /// 地図を選んだ・追加した・受信したあとに呼ぶ（マップ画面へ戻る）。
  final VoidCallback onDone;
  final MapReceiveHost? mapReceiveHost;

  const MapSwitchTab({
    super.key,
    required this.status,
    required this.statusAnnouncement,
    required this.notice,
    required this.onStatusPressed,
    required this.activeMap,
    required this.maps,
    required this.onMapSelected,
    required this.onMapAdded,
    required this.onMapDeleted,
    required this.onDone,
    this.mapReceiveHost,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 72, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    AppStrings.mapsTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: MapManagementPanel(
                    activeMap: activeMap,
                    maps: maps,
                    onSelect: onMapSelected,
                    onAdd: onMapAdded,
                    onDelete: onMapDeleted,
                    onDone: onDone,
                    receiveHost: mapReceiveHost,
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
