import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_service.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
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
  late final BleService _bleService;

  BleStatus _status = BleStatus.idle;
  final List<String> _logs = [];

  // フォームコントローラー（各ポリゴン頂点）
  // シンプルに4頂点固定で入力フォームを用意する
  final List<TextEditingController> _xControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _yControllers = List.generate(4, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _bleService = BleService(
      onLog: (msg) {
        setState(() => _logs.insert(0, '${_timestamp()} $msg'));
      },
      onStatusChanged: (s) {
        setState(() => _status = s);
      },
    );
    _setDefaultValues();
  }

  void _setDefaultValues() {
    // デフォルトの正方形ゾーン（テスト用）
    final defaults = [
      [1.0, 1.0],
      [4.0, 1.0],
      [4.0, 3.0],
      [1.0, 3.0],
    ];
    for (int i = 0; i < 4; i++) {
      _xControllers[i].text = defaults[i][0].toString();
      _yControllers[i].text = defaults[i][1].toString();
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}]';
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied = statuses.entries.where((e) => !e.value.isGranted).toList();
    if (denied.isNotEmpty) {
      setState(() => _logs.insert(0, '❌ パーミッション不足: ${denied.map((e) => e.key).join(', ')}'));
    }
  }

  Future<void> _onConnectPressed() async {
    await _requestPermissions();
    await _bleService.scanAndConnect();
  }

  Future<void> _onSendPressed() async {
    // フォームから座標を取得してJSONを組み立てる
    final List<Map<String, double>> polygon = [];
    for (int i = 0; i < 4; i++) {
      final x = double.tryParse(_xControllers[i].text);
      final y = double.tryParse(_yControllers[i].text);
      if (x == null || y == null) {
        setState(() => _logs.insert(0, '❌ 頂点[$i] の値が不正です'));
        return;
      }
      polygon.add({'x': x, 'y': y});
    }

    final zone = {
      'type': 'cleaning_zone',
      'frame_id': 'map',
      'polygon': polygon,
    };

    await _bleService.sendCleaningZone(zone);
  }

  Future<void> _onDisconnectPressed() async {
    await _bleService.disconnect();
  }

  @override
  void dispose() {
    _bleService.dispose();
    for (final c in _xControllers) {
      c.dispose();
    }
    for (final c in _yControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIRS BLE クライアント'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 接続状態バー ---
            _StatusBar(status: _status),
            const SizedBox(height: 16),

            // --- 接続ボタン群 ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_status == BleStatus.idle || _status == BleStatus.disconnected || _status == BleStatus.error)
                            ? _onConnectPressed
                            : null,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('スキャン & 接続'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _status == BleStatus.connected ? _onDisconnectPressed : null,
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('切断'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- 清掃範囲入力フォーム ---
            const Text(
              '清掃範囲 (map座標, m)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._buildPolygonForm(),

            const SizedBox(height: 12),

            // --- 送信ボタン ---
            ElevatedButton.icon(
              onPressed: _status == BleStatus.connected ? _onSendPressed : null,
              icon: const Icon(Icons.send),
              label: const Text('送信 (BLE Write)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // --- ログ表示 ---
            const Text(
              'ログ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (_, i) => Text(
                    _logs[i],
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
    );
  }

  List<Widget> _buildPolygonForm() {
    return List.generate(4, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text('頂点 ${i + 1}', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _xControllers[i],
                decoration: const InputDecoration(
                  labelText: 'X (m)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _yControllers[i],
                decoration: const InputDecoration(
                  labelText: 'Y (m)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// 接続状態を色付きバーで表示するウィジェット
class _StatusBar extends StatelessWidget {
  final BleStatus status;

  const _StatusBar({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      BleStatus.idle => (Colors.grey, Icons.bluetooth, '未接続'),
      BleStatus.scanning => (Colors.orange, Icons.bluetooth_searching, 'スキャン中...'),
      BleStatus.connecting => (Colors.orange, Icons.bluetooth_searching, '接続中...'),
      BleStatus.connected => (Colors.green, Icons.bluetooth_connected, '接続済み'),
      BleStatus.sending => (Colors.blue, Icons.upload, '送信中...'),
      BleStatus.disconnected => (Colors.grey, Icons.bluetooth_disabled, '切断済み'),
      BleStatus.error => (Colors.red, Icons.error, 'エラー'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
