import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/initial_pose.dart';
import '../models/map_geometry.dart';

/// 開始地点の確定値ホルダーとドラッグ→yaw変換の純粋関数群。
///
/// ドラッグ中の途中状態は `MapSelectionArea` が持ち、確定時のみ
/// `pose` に反映する（Single Source of Truth）。
class InitialPoseController {
  /// 向き確定に必要な最小ドラッグ距離（地図ローカル座標上の論理px）。
  static const double minDragDistance = 24.0;

  InitialPoseMission? pose;

  bool get hasPose => pose != null;

  void clear() {
    pose = null;
  }

  /// ドラッグが向き確定に足る長さか判定する。
  static bool isDragValid(Offset start, Offset end) =>
      (end - start).distance >= minDragDistance;

  /// ドラッグ始終点（地図ローカル座標）からmap座標系のyaw[rad]を求める。
  ///
  /// `fromLocal` が画面Y反転を吸収するため、atan2の結果はそのまま
  /// ROSのyaw（反時計回り正）として使える。
  static double yawFromLocalDrag(Offset start, Offset end, Size mapSize) {
    final a = MapGeometry.fromLocal(start, mapSize);
    final b = MapGeometry.fromLocal(end, mapSize);
    return math.atan2(b.y - a.y, b.x - a.x);
  }
}
