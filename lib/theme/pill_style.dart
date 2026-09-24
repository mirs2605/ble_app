import 'package:flutter/material.dart';

import '../models/send_button_state.dart';
import '../services/ble_service.dart';
import 'app_colors.dart';

/// ピル型UI（通知バー・ステータス・送信ボタン）の深刻度。
enum PillSeverity { neutral, info, success, warning, error }

/// ピルの見た目。グラデーションの実値はテーマ層のここに集約し、
/// 各Widgetはこのオブジェクトを外から受け取るだけにする。
@immutable
class PillStyle {
  final Gradient gradient;
  final Color foreground;
  final Color borderColor;
  final double borderRadius;

  const PillStyle({
    required this.gradient,
    this.foreground = AppColors.onColor,
    this.borderColor = Colors.white54,
    this.borderRadius = 22,
  });
}

/// グラデーションとアイコンの解決を一手に担うファクトリ。
/// Widget側に `Colors.xxx.shadeYYY` や `BleStatus -> IconData` の
/// ハードコードを持たせないための疎結合ポイント。
abstract final class PillStyles {
  static const _begin = Alignment.topLeft;
  static const _end = Alignment.bottomRight;

  static PillStyle _glass(Color start, Color end, {double borderRadius = 22}) {
    return PillStyle(
      gradient: LinearGradient(
        begin: _begin,
        end: _end,
        colors: [
          start.withValues(alpha: 0.55),
          end.withValues(alpha: 0.55),
        ],
      ),
      borderRadius: borderRadius,
    );
  }

  /// Bluetooth接続状態に対応するピル。第2戻り値は状態アイコン。
  static (PillStyle, IconData) forBleStatus(BleStatus status) {
    return switch (status) {
      BleStatus.idle => (
          _glass(Colors.grey.shade700, Colors.grey.shade300),
          Icons.bluetooth,
        ),
      BleStatus.scanning || BleStatus.connecting => (
          _glass(Colors.orange.shade700, Colors.amber.shade400),
          Icons.bluetooth_searching,
        ),
      BleStatus.connected => (
          _glass(Colors.green.shade700, Colors.lightGreen.shade300),
          Icons.bluetooth_connected,
        ),
      // 送信中は接続色を維持し、BTアイコンを反応させない方針。
      BleStatus.sending => (
          _glass(Colors.green.shade700, Colors.lightGreen.shade300),
          Icons.bluetooth_connected,
        ),
      BleStatus.disconnected => (
          _glass(Colors.grey.shade700, Colors.grey.shade300),
          Icons.bluetooth_disabled,
        ),
      BleStatus.error => (
          _glass(Colors.red.shade700, Colors.orange.shade400),
          Icons.error,
        ),
    };
  }

  /// 通知バー用のニュートラル系ピル。深刻度で色を変えたい場合は
  /// [forSeverity] を使う。
  static PillStyle notification() =>
      _glass(Colors.grey.shade800, Colors.grey.shade600);

  static PillStyle forSeverity(PillSeverity severity) => switch (severity) {
    PillSeverity.neutral => _glass(Colors.grey.shade800, Colors.grey.shade600),
    PillSeverity.info => _glass(Colors.blue.shade700, Colors.blue.shade300),
    PillSeverity.success =>
      _glass(Colors.green.shade700, Colors.lightGreen.shade300),
    PillSeverity.warning =>
      _glass(Colors.orange.shade700, Colors.amber.shade400),
    PillSeverity.error => _glass(Colors.red.shade700, Colors.orange.shade400),
  };

  /// 送信ボタンの状態に対応するピル。
  static PillStyle forSendState(SendButtonState state) => switch (state) {
    SendButtonState.ready =>
      _glass(Colors.blue.shade700, Colors.blue.shade300, borderRadius: 28),
    SendButtonState.sending =>
      _glass(Colors.orange.shade700, Colors.amber.shade400, borderRadius: 28),
    SendButtonState.completed =>
      _glass(Colors.green.shade700, Colors.lightGreen.shade300,
          borderRadius: 28),
  };

  /// 破壊的操作（範囲削除など）のピル。
  static PillStyle destructive() =>
      _glass(Colors.red.shade700, Colors.orange.shade400, borderRadius: 28);
}
