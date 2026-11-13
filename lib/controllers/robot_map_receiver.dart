import 'package:flutter/foundation.dart';

import '../models/map_config.dart';
import '../services/ble_connection.dart';
import '../services/pgm_codec.dart';
import '../theme/app_strings.dart';

/// ロボットが SLAM で作った地図を BLE で受け取り、地図として登録する協調役。
///
/// 受信（[BleConnection]）・画像の保存・地図の登録は外から渡された関数に委ね、
/// ここは手順（情報→データ→PNG化→検証→保存→登録）と進捗に徹する。
class RobotMapReceiver extends ChangeNotifier {
  RobotMapReceiver({
    required this.connection,
    required this.saveImage,
    required this.deleteImage,
    required this.addMap,
    required this.isConnected,
    required this.onLog,
  });

  final BleConnection connection;
  final Future<String> Function(Uint8List png) saveImage;
  final Future<void> Function(String path) deleteImage;
  final Future<void> Function(MapConfig map) addMap;
  final bool Function() isConnected;
  final void Function(String message) onLog;

  bool _busy = false;
  double _progress = 0;

  /// 受信中か。受信中は新しい受信を始めない。
  bool get busy => _busy;

  /// 受信の進み具合（0〜1）。受信していないときは 0。
  double get progress => _progress;

  bool get canReceive => !_busy && isConnected();

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// 受信して地図を登録する。成功したら true。失敗の理由はログに出す。
  Future<bool> receive() async {
    if (_busy) return false;
    if (!isConnected()) {
      onLog('❌ 未接続です。先に接続してください。');
      return false;
    }
    _busy = true;
    _progress = 0;
    _changed();
    String? savedPath;
    try {
      final info = await connection.pullMapInfo();
      if (info == null) return false;
      onLog(AppStrings.mapReceiveStart(info.name, info.size));

      final data = await connection.pullMapData(
        info,
        onProgress: (received, total) {
          _progress = total == 0 ? 0 : received / total;
          _changed();
        },
      );
      if (data == null) return false;

      final png = info.isPgm ? await pgmToPng(data) : data;
      final size = pngDimensions(png);
      if (size == null) {
        onLog('❌ 受信した地図が画像として読めません。');
        return false;
      }
      if (size.$1 != info.width || size.$2 != info.height) {
        onLog(
          '❌ 地図の寸法が説明と違います '
          '(説明 ${info.width}×${info.height} / 実際 ${size.$1}×${size.$2})。',
        );
        return false;
      }

      savedPath = await saveImage(png);
      await addMap(
        MapConfig(
          name: info.name,
          assetPath: savedPath,
          resolution: info.resolution,
          originX: info.originX,
          originY: info.originY,
          imageWidth: info.width.toDouble(),
          imageHeight: info.height.toDouble(),
        ),
      );
      savedPath = null;
      onLog(AppStrings.mapReceiveDone(info.name));
      return true;
    } on FormatException catch (e) {
      onLog('❌ 地図を変換できませんでした: ${e.message}');
      return false;
    } catch (e) {
      onLog('❌ 地図を登録できませんでした: $e');
      return false;
    } finally {
      // 登録まで進まなかった画像は残さない。
      final orphan = savedPath;
      if (orphan != null) await deleteImage(orphan);
      _busy = false;
      _progress = 0;
      _changed();
    }
  }
}
