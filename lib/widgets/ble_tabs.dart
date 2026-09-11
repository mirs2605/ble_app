import 'package:flutter/material.dart';

import '../models/cleaning_zone.dart';
import '../models/send_button_state.dart';
import '../services/ble_service.dart';
import 'ble_status_indicator.dart';
import 'floating_action_controls.dart';
import 'map_selection_area.dart';
import 'polygon_form.dart';

class BleHomeTab extends StatelessWidget {
  final List<MapPoint> selectedMapPoints;
  final BleStatus status;
  final String? statusAnnouncement;
  final IconData? announcementIcon;
  final bool permissionsPermanentlyDenied;
  final ValueChanged<List<MapPoint>> onMapChanged;
  final ValueChanged<String> onLog;
  final VoidCallback onPermissionSettings;
  final VoidCallback onClearSelection;
  final VoidCallback onSend;
  final VoidCallback onStatusPressed;
  final bool sendCompleted;
  final bool canSend;
  final SendButtonState sendButtonState;

  const BleHomeTab({
    super.key,
    required this.selectedMapPoints,
    required this.status,
    required this.statusAnnouncement,
    required this.announcementIcon,
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
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MapSelectionArea(
          points: selectedMapPoints,
          onChanged: onMapChanged,
          onLog: onLog,
          sendCompleted: sendCompleted,
        ),
        _TopLeftStatus(
          status: status,
          announcement: statusAnnouncement,
          announcementIcon: announcementIcon,
          onPressed: onStatusPressed,
        ),
        if (permissionsPermanentlyDenied)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: PermissionSettingsButton(
                  onPressed: onPermissionSettings,
                ),
              ),
            ),
          ),
        MapSelectionActions(
          showClear: selectedMapPoints.length >= 4,
          showSend: selectedMapPoints.length >= 4,
          canSend: canSend,
          sendButtonState: sendButtonState,
          onClear: onClearSelection,
          onSend: onSend,
        ),
      ],
    );
  }
}

class BleValuesTab extends StatelessWidget {
  final List<TextEditingController> xControllers;
  final List<TextEditingController> yControllers;
  final BleStatus status;
  final String? statusAnnouncement;
  final IconData? announcementIcon;
  final VoidCallback onSend;
  final VoidCallback onStatusPressed;
  final bool sendCompleted;
  final SendButtonState sendButtonState;

  const BleValuesTab({
    super.key,
    required this.xControllers,
    required this.yControllers,
    required this.status,
    required this.statusAnnouncement,
    required this.announcementIcon,
    required this.onSend,
    required this.onStatusPressed,
    required this.sendCompleted,
    required this.sendButtonState,
  });

  @override
  Widget build(BuildContext context) {
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
                    '清掃範囲 (map座標, m)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  PolygonForm(
                    xControllers: xControllers,
                    yControllers: yControllers,
                  ),
                ],
              ),
            ),
          ),
        ),
        _TopLeftStatus(
          status: status,
          announcement: statusAnnouncement,
          announcementIcon: announcementIcon,
          onPressed: onStatusPressed,
        ),
        BottomSendAction(
          heroTag: 'send-values',
          enabled: status == BleStatus.connected,
          onPressed: onSend,
          state: sendButtonState,
        ),
      ],
    );
  }
}

class BleLogsTab extends StatelessWidget {
  final List<String> logs;
  final BleStatus status;
  final String? statusAnnouncement;
  final IconData? announcementIcon;
  final VoidCallback onSend;
  final VoidCallback onStatusPressed;
  final bool sendCompleted;
  final SendButtonState sendButtonState;

  const BleLogsTab({
    super.key,
    required this.logs,
    required this.status,
    required this.statusAnnouncement,
    required this.announcementIcon,
    required this.onSend,
    required this.onStatusPressed,
    required this.sendCompleted,
    required this.sendButtonState,
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
                const Text('ログ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (_, index) => Text(
                        logs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
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
          announcementIcon: announcementIcon,
          onPressed: onStatusPressed,
        ),
        BottomSendAction(
          heroTag: 'send-logs',
          enabled: status == BleStatus.connected,
          onPressed: onSend,
          state: sendButtonState,
        ),
      ],
    );
  }
}

class _TopLeftStatus extends StatelessWidget {
  final BleStatus status;
  final String? announcement;
  final IconData? announcementIcon;
  final VoidCallback? onPressed;

  const _TopLeftStatus({
    required this.status,
    required this.announcement,
    required this.announcementIcon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: BleStatusIndicator(
            status: status,
            announcement: announcement,
            announcementIcon: announcementIcon,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
