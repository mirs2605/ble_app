import 'dart:math' as math;

import 'cleaning_zone.dart';
import 'map_config.dart';
import 'map_geometry.dart';

/// 清掃範囲のひな形。単位円に収まる単純多角形（自己交差なし）を持つ。
///
/// 頂点は反時計回り・y 上向き（地図座標系と同じ向き）。頂点数は
/// [MapGeometry.maxFreehandVertexCount] 以下に保つ。
class ShapeTemplate {
  final String id;
  final String label;
  final List<MapPoint> unitVertices;

  const ShapeTemplate._(this.id, this.label, this.unitVertices);

  int get vertexCount => unitVertices.length;

  /// 地図の中央に、短辺の [sizeRatio] 倍の半径で配置した頂点列を返す。
  List<MapPoint> placeOn([MapConfig? config, double sizeRatio = 0.35]) {
    final ox = config?.originX ?? MapGeometry.originX;
    final oy = config?.originY ?? MapGeometry.originY;
    final wm = config?.widthMeters ?? MapGeometry.widthMeters;
    final hm = config?.heightMeters ?? MapGeometry.heightMeters;
    final cx = ox + wm / 2;
    final cy = oy + hm / 2;
    final radius = math.min(wm, hm) * sizeRatio;
    return unitVertices
        .map((p) => MapPoint(x: cx + p.x * radius, y: cy + p.y * radius))
        .toList();
  }

  /// 外側 [points] 個の頂点と内側 [points] 個の頂点を交互に並べた星形。
  /// 先端を真上に向ける。
  static List<MapPoint> _star(int points, double innerRatio) {
    final step = math.pi / points;
    return List<MapPoint>.generate(points * 2, (i) {
      final r = i.isEven ? 1.0 : innerRatio;
      final angle = math.pi / 2 + i * step;
      return MapPoint(x: r * math.cos(angle), y: r * math.sin(angle));
    });
  }

  static List<MapPoint> _fromPairs(List<List<double>> pairs) =>
      pairs.map((p) => MapPoint(x: p[0], y: p[1])).toList();

  /// 五芒星の外形（凹10角形）。
  static final ShapeTemplate star = ShapeTemplate._(
    'star',
    '星',
    _star(5, 0.382),
  );

  /// 四角の星（凹8角形）。
  static final ShapeTemplate fourPointStar = ShapeTemplate._(
    'four_point_star',
    '四角星',
    _star(4, 0.4),
  );

  /// 六芒星の外形（凹12角形）。
  static final ShapeTemplate hexagram = ShapeTemplate._(
    'hexagram',
    '六芒星',
    _star(6, 1 / math.sqrt(3)),
  );

  /// 十字（凹12角形）。
  static final ShapeTemplate cross = ShapeTemplate._(
    'cross',
    '十字',
    _fromPairs([
      [-0.35, -1],
      [0.35, -1],
      [0.35, -0.35],
      [1, -0.35],
      [1, 0.35],
      [0.35, 0.35],
      [0.35, 1],
      [-0.35, 1],
      [-0.35, 0.35],
      [-1, 0.35],
      [-1, -0.35],
      [-0.35, -0.35],
    ]),
  );

  /// 上向きの矢印（凹7角形）。
  static final ShapeTemplate arrow = ShapeTemplate._(
    'arrow',
    '矢印',
    _fromPairs([
      [-0.35, -1],
      [0.35, -1],
      [0.35, 0.1],
      [0.85, 0.1],
      [0, 1],
      [-0.85, 0.1],
      [-0.35, 0.1],
    ]),
  );

  /// L 字（凹6角形）。
  static final ShapeTemplate lShape = ShapeTemplate._(
    'l_shape',
    'L字',
    _fromPairs([
      [-1, -1],
      [1, -1],
      [1, -0.3],
      [-0.3, -0.3],
      [-0.3, 1],
      [-1, 1],
    ]),
  );

  /// コの字（凹8角形）。
  static final ShapeTemplate uShape = ShapeTemplate._(
    'u_shape',
    'コの字',
    _fromPairs([
      [-1, -1],
      [1, -1],
      [1, 1],
      [0.35, 1],
      [0.35, -0.35],
      [-0.35, -0.35],
      [-0.35, 1],
      [-1, 1],
    ]),
  );

  static final List<ShapeTemplate> all = <ShapeTemplate>[
    star,
    fourPointStar,
    hexagram,
    cross,
    arrow,
    lShape,
    uShape,
  ];
}
