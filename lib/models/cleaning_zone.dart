/// 2次元座標モデル (メートル単位)
class MapPoint {
  final double x;
  final double y;

  const MapPoint({required this.x, required this.y});

  Map<String, double> toJson() => {'x': x, 'y': y};

  factory MapPoint.fromJson(Map<String, dynamic> json) {
    final x = json['x'];
    final y = json['y'];
    if (x is! num || y is! num) {
      throw const FormatException('MapPoint requires numeric x and y values');
    }
    return MapPoint(x: x.toDouble(), y: y.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is MapPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'MapPoint(x: $x, y: $y)';
}

/// 清掃範囲ミッション定義モデル
class CleaningZoneMission {
  static const double maxCoordinateAbs = 1000.0;
  static const double minArea = 0.0001;
  static const int minPoints = 3;

  final String type;
  final String frameId;
  final List<MapPoint> polygon;

  const CleaningZoneMission({
    this.type = 'cleaning_zone',
    this.frameId = 'map',
    required this.polygon,
  });

  /// ROS 2 ノードが期待する JSON Map にシリアライズ
  Map<String, dynamic> toJson() => {
    'type': type,
    'frame_id': frameId,
    'polygon': polygon.map((p) => p.toJson()).toList(),
  };

  /// 任意ポリゴンとしての清掃範囲を検証する。
  bool get isValid {
    if (!(type.isNotEmpty &&
        frameId.isNotEmpty &&
        polygon.length >= minPoints &&
        polygon.every(
          (p) =>
              p.x.isFinite &&
              p.y.isFinite &&
              p.x.abs() <= maxCoordinateAbs &&
              p.y.abs() <= maxCoordinateAbs,
        ))) {
      return false;
    }

    for (var i = 0; i < polygon.length; i++) {
      for (var j = i + 1; j < polygon.length; j++) {
        if (polygon[i] == polygon[j]) return false;
      }
    }

    if (_signedArea.abs() < minArea) return false;

    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      for (var j = i + 1; j < polygon.length; j++) {
        if (j == i || (j == (i + 1) % polygon.length)) continue;
        if (i == 0 && j == polygon.length - 1) continue;
        final c = polygon[j];
        final d = polygon[(j + 1) % polygon.length];
        if (_segmentsIntersect(a, b, c, d)) return false;
      }
    }
    return true;
  }

  double get _signedArea {
    var area = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final next = polygon[(i + 1) % polygon.length];
      area += current.x * next.y - next.x * current.y;
    }
    return area / 2;
  }

  bool _segmentsIntersect(MapPoint a, MapPoint b, MapPoint c, MapPoint d) {
    double cross(MapPoint p, MapPoint q, MapPoint r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    final abC = cross(a, b, c);
    final abD = cross(a, b, d);
    final cdA = cross(c, d, a);
    final cdB = cross(c, d, b);
    return (abC > 0 && abD < 0 || abC < 0 && abD > 0) &&
        (cdA > 0 && cdB < 0 || cdA < 0 && cdB > 0);
  }
}
