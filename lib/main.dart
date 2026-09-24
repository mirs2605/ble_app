import 'package:flutter/material.dart';

import 'controllers/ble_home_controller.dart';
import 'theme/app_colors.dart';
import 'widgets/ble_tabs.dart';
import 'widgets/icon_tab_navigation.dart';

void main() {
  runApp(const MirsBleApp());
}

class MirsBleApp extends StatelessWidget {
  const MirsBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIRS BLE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.action,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const BleHomePage(),
    );
  }
}

class BleHomePage extends StatefulWidget {
  const BleHomePage({super.key});

  @override
  State<BleHomePage> createState() => _BleHomePageState();
}

class _BleHomePageState extends State<BleHomePage> {
  late final BleHomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BleHomeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _controller.selectedTabIndex,
            children: [
              BleValuesTab(
                status: _controller.status,
                statusAnnouncement: _controller.statusAnnouncement,
                notice: _controller.activeNotice,
                selectedMapPoints: _controller.selectedMapPoints,
                onSendPolygon: _controller.sendPolygon,
                canSendPolygon: _controller.canSendPolygon,
                onStatusPressed: _controller.showStatusAnnouncement,
                sendButtonState: _controller.sendButtonState,
              ),
              BleHomeTab(
                mapSelection: _controller.mapSelection,
                status: _controller.status,
                statusAnnouncement: _controller.statusAnnouncement,
                notice: _controller.activeNotice,
                permissionsPermanentlyDenied:
                    _controller.permissionsPermanentlyDenied,
                onMapChanged: _controller.setSelectedMapPoints,
                onSelectionIdleChanged: _controller.setSelectionIdle,
                onLog: _controller.addLog,
                onPermissionSettings: _controller.openPermissionSettings,
                onClearSelection: _controller.clearSelection,
                onSend: _controller.sendPressed,                onStatusPressed: _controller.showStatusAnnouncement,
                sendCompleted: _controller.sendCompleted,
                sendButtonState: _controller.sendButtonState,
                canSend: _controller.canSendSelectedMap,
              ),
              BleLogsTab(
                logs: _controller.logs,
                status: _controller.status,
                statusAnnouncement: _controller.statusAnnouncement,
                notice: _controller.activeNotice,
                onStatusPressed: _controller.showStatusAnnouncement,
              ),
            ],
          ),
          bottomNavigationBar: IconTabNavigation(
            currentIndex: _controller.selectedTabIndex,
            onTap: _controller.selectTab,
          ),
        );
      },
    );
  }
}
