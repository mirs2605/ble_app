import 'dart:math' as math;

/// ロボットの開始地点（2D Pose Estimate）モデル。
///
/// [x], [y] はmap座標系でのメートル単位位置。
/// [yaw] はmap座標系でのラジアン単位の向き（正のyaw = 反時計回り）。
class InitialPoseMission {
  static const double maxCoordinateAbs = 1000.0;

  final String type;
  final String frameId;
  final double x;
  final double y;
  final double yaw;

  const InitialPoseMission({
    this.type = 'initial_pose',
    this.frameId = 'map',
    required this.x,
    required this.y,
    this.yaw = 0.0,
  });

  /// ROS 2ノードが期待するJSONにシリアライズする。
  Map<String, dynamic> toJson() => {
    'type': type,
    'frame_id': frameId,
    'x': x,
    'y': y,
    'yaw': yaw,
  };

  /// 値の妥当性を検証する。
  bool get isValid =>
      type.isNotEmpty &&
      frameId.isNotEmpty &&
      x.isFinite &&
      y.isFinite &&
      yaw.isFinite &&
      x.abs() <= maxCoordinateAbs &&
      y.abs() <= maxCoordinateAbs;

  /// yawを度数法に変換したもの（表示用）。
  double get yawDegrees => yaw * 180.0 / math.pi;

  @override
  String toString() =>
      'InitialPoseMission(x: $x, y: $y, yaw: ${yawDegrees.toStringAsFixed(1)}°)';
}
