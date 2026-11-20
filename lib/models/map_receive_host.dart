import 'package:flutter/foundation.dart';

/// 地図管理ダイアログから「ロボットの地図を受信」を呼ぶための窓口。
/// Controller の型を画面に持ち込まないための薄いインターフェース。
class MapReceiveHost {
  const MapReceiveHost({
    required this.listenable,
    required this.canReceive,
    required this.progress,
    required this.onReceive,
  });

  /// 受信の状態が変わったときに通知される。
  final Listenable listenable;
  final bool Function() canReceive;

  /// 受信の進み具合（0〜1）。受信中でなければ null。
  final double? Function() progress;

  /// 受信して地図を登録する。成功したら true。
  final Future<bool> Function() onReceive;
}
