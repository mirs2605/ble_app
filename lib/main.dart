import 'package:flutter/material.dart';

import 'controllers/ble_home_controller.dart';
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
          seedColor: Colors.blue,
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
                xControllers: _controller.xControllers,
                yControllers: _controller.yControllers,
                status: _controller.status,
                statusAnnouncement: _controller.statusAnnouncement,
                announcementIcon: _controller.announcementIcon,
                onSend: _controller.sendPressed,
                onStatusPressed: _controller.showStatusAnnouncement,
                sendCompleted: _controller.sendCompleted,
                sendButtonState: _controller.sendButtonState,
              ),
              BleHomeTab(
                selectedMapPoints: _controller.selectedMapPoints,
                status: _controller.status,
                statusAnnouncement: _controller.statusAnnouncement,
                announcementIcon: _controller.announcementIcon,
                permissionsPermanentlyDenied:
                    _controller.permissionsPermanentlyDenied,
                onMapChanged: _controller.setSelectedMapPoints,
                onLog: _controller.addLog,
                onPermissionSettings: _controller.openPermissionSettings,
                onClearSelection: _controller.clearSelection,
                onSend: _controller.sendPressed,
                onStatusPressed: _controller.showStatusAnnouncement,
                sendCompleted: _controller.sendCompleted,
                sendButtonState: _controller.sendButtonState,
                canSend: _controller.canSendSelectedMap,
              ),
              BleLogsTab(
                logs: _controller.logs,
                status: _controller.status,
                statusAnnouncement: _controller.statusAnnouncement,
                announcementIcon: _controller.announcementIcon,
                onSend: _controller.sendPressed,
                onStatusPressed: _controller.showStatusAnnouncement,
                sendCompleted: _controller.sendCompleted,
                sendButtonState: _controller.sendButtonState,
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
