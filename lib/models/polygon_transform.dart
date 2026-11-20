import 'dart:math' as math;
import 'dart:ui';

import 'cleaning_zone.dart';
import 'map_config.dart';
import 'map_geometry.dart';

/// 多角形の当たり判定（頂点・辺・面）と幾何変換（頂点移動・辺平行移動・面平行移動・中心基準拡縮）を担う純粋関数群。
///
/// 状態やUIを持たず、[MapGeometry] の座標変換のみに依存する。
abstract final class PolygonTransform {
  static const double defaultHitTolerance = 18.0;
  static const double minRadiusMeters = 0.1;

  /// 画面上の点 [p] から線分 [a]-[b] までの最短距離を返す。
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared <= 1e-9) {
      return (p - a).distance;
    }
    final t =
        (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared)
            .clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  /// [localPosition] から [tolerance] 以内にある最も近い頂点のインデックスを返す。
  static int? hitVertex(
    List<MapPoint> polygon,
    Offset localPosition,
    Size size, {
    MapConfig? config,
    double tolerance = defaultHitTolerance,
  }) {
    if (polygon.length < CleaningZoneMission.minPoints) return null;

    int? closestIndex;
    var closestDistance = tolerance;
    for (int i = 0; i < polygon.length; i++) {
      final point = MapGeometry.toScreenPoint(polygon[i], size, config);
      final distance = (point - localPosition).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  /// [localPosition] から [tolerance] 以内にある最も近い辺の始点インデックスを返す。
  static int? hitEdge(
    List<MapPoint> polygon,
    Offset localPosition,
    Size size, {
    MapConfig? config,
    double tolerance = defaultHitTolerance,
  }) {
    if (polygon.length < CleaningZoneMission.minPoints) return null;

    int? closestEdge;
    var closestDistance = tolerance;
    final n = polygon.length;
    for (int i = 0; i < n; i++) {
      final a = MapGeometry.toScreenPoint(polygon[i], size, config);
      final b = MapGeometry.toScreenPoint(polygon[(i + 1) % n], size, config);
      final distance = distanceToSegment(localPosition, a, b);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestEdge = i;
      }
    }
    return closestEdge;
  }

  /// 画面座標 [localPosition] が多角形 [polygon] の内部にあるか判定する。
  static bool containsScreenPoint(
    List<MapPoint> polygon,
    Offset localPosition,
    Size size, [
    MapConfig? config,
  ]) {
    if (polygon.length < CleaningZoneMission.minPoints) return false;
    var inside = false;
    final n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final pi = MapGeometry.toScreenPoint(polygon[i], size, config);
      final pj = MapGeometry.toScreenPoint(polygon[j], size, config);
      final intersects =
          ((pi.dy > localPosition.dy) != (pj.dy > localPosition.dy)) &&
          (localPosition.dx <
              (pj.dx - pi.dx) *
                      (localPosition.dy - pi.dy) /
                      (pj.dy - pi.dy) +
                  pi.dx);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  /// 多角形の外接矩形の中心を返す。
  static MapPoint boundingCenter(List<MapPoint> polygon) {
    if (polygon.isEmpty) return const MapPoint(x: 0, y: 0);
    final minX = polygon.map((p) => p.x).reduce(math.min);
    final maxX = polygon.map((p) => p.x).reduce(math.max);
    final minY = polygon.map((p) => p.y).reduce(math.min);
    final maxY = polygon.map((p) => p.y).reduce(math.max);
    return MapPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2);
  }

  /// [points] の全頂点が地図範囲内に収まるよう平行移動量 [deltaMeters] を制限する。
  static Offset clampTranslation(
    List<MapPoint> points,
    Offset deltaMeters, [
    MapConfig? config,
  ]) {
    if (points.isEmpty) return Offset.zero;
    final ox = config?.originX ?? MapGeometry.originX;
    final oy = config?.originY ?? MapGeometry.originY;
    final wm = config?.widthMeters ?? MapGeometry.widthMeters;
    final hm = config?.heightMeters ?? MapGeometry.heightMeters;

    final minX = points.map((p) => p.x).reduce(math.min);
    final maxX = points.map((p) => p.x).reduce(math.max);
    final minY = points.map((p) => p.y).reduce(math.min);
    final maxY = points.map((p) => p.y).reduce(math.max);

    final lowDx = ox - minX;
    final highDx = ox + wm - maxX;
    final lowDy = oy - minY;
    final highDy = oy + hm - maxY;

    return Offset(
      lowDx <= highDx ? deltaMeters.dx.clamp(lowDx, highDx) : 0.0,
      lowDy <= highDy ? deltaMeters.dy.clamp(lowDy, highDy) : 0.0,
    );
  }

  /// 1つの頂点 [vertexIndex] を [localPosition] に移動した新しい頂点列を返す。
  static List<MapPoint> moveVertex(
    List<MapPoint> polygon,
    int vertexIndex,
    Offset localPosition,
    Size size, [
    MapConfig? config,
  ]) {
    final next = List<MapPoint>.from(polygon);
    next[vertexIndex] = MapGeometry.fromLocal(localPosition, size, config);
    return next;
  }

  /// 辺 [edgeIndex]（両端の2頂点）を画面上の移動量 [screenDelta] 分だけ平行移動した頂点列を返す。
  static List<MapPoint> translateEdgeByScreenDelta(
    List<MapPoint> polygon,
    int edgeIndex,
    Offset screenDelta,
    Size size, [
    MapConfig? config,
  ]) {
    if (polygon.length < CleaningZoneMission.minPoints) {
      return List<MapPoint>.from(polygon);
    }
    final i = edgeIndex % polygon.length;
    final j = (i + 1) % polygon.length;
    final deltaMeters = MapGeometry.screenDeltaToMeters(
      screenDelta,
      size,
      config,
    );
    final clamped = clampTranslation(
      [polygon[i], polygon[j]],
      deltaMeters,
      config,
    );
    final next = List<MapPoint>.from(polygon);
    next[i] = MapPoint(
      x: polygon[i].x + clamped.dx,
      y: polygon[i].y + clamped.dy,
    );
    next[j] = MapPoint(
      x: polygon[j].x + clamped.dx,
      y: polygon[j].y + clamped.dy,
    );
    return next;
  }

  /// 面全体を画面上の移動量 [screenDelta] 分だけ平行移動した頂点列と適用された移動量（メートル）を返す。
  static ({List<MapPoint> points, Offset appliedDelta})
  translateFaceByScreenDelta(
    List<MapPoint> polygon,
    Offset screenDelta,
    Size size, [
    MapConfig? config,
  ]) {
    final deltaMeters = MapGeometry.screenDeltaToMeters(
      screenDelta,
      size,
      config,
    );
    final clamped = clampTranslation(polygon, deltaMeters, config);
    final points = polygon
        .map((p) => MapPoint(x: p.x + clamped.dx, y: p.y + clamped.dy))
        .toList();
    return (points: points, appliedDelta: clamped);
  }

  /// ハンドル操作の開始位置 [startLocal] と現在位置 [currentLocal] から、
  /// [center] 基準で拡大縮小した頂点列を返す。
  static List<MapPoint> scaleFromHandleDrag({
    required List<MapPoint> polygon,
    required MapPoint center,
    required int handleIndex,
    required Offset? startLocal,
    required Offset currentLocal,
    required Size size,
    MapConfig? config,
  }) {
    if (polygon.length < CleaningZoneMission.minPoints) {
      return List<MapPoint>.from(polygon);
    }
    final handleVertex = polygon[handleIndex % polygon.length];
    final startPoint = startLocal != null
        ? MapGeometry.fromLocal(startLocal, size, config)
        : handleVertex;
    final currentPoint = MapGeometry.fromLocal(currentLocal, size, config);

    final rStart = _distance(startPoint, center);
    final rVertex = _distance(handleVertex, center);
    final rBase = rStart > 1e-6 ? rStart : rVertex;
    final rCurrent = _distance(currentPoint, center);
    final rawScale = rBase > 1e-6 ? rCurrent / rBase : 1.0;

    return scaleAround(polygon, center, rawScale, config);
  }

  /// [center] を基準に [polygon] を [rawScale] 倍した頂点列を返す。
  /// 全頂点が地図範囲内に収まり、最小サイズを下回らないよう倍率を制限する。
  static List<MapPoint> scaleAround(
    List<MapPoint> polygon,
    MapPoint center,
    double rawScale, [
    MapConfig? config,
  ]) {
    if (polygon.length < CleaningZoneMission.minPoints) {
      return List<MapPoint>.from(polygon);
    }
    final ox = config?.originX ?? MapGeometry.originX;
    final oy = config?.originY ?? MapGeometry.originY;
    final wm = config?.widthMeters ?? MapGeometry.widthMeters;
    final hm = config?.heightMeters ?? MapGeometry.heightMeters;

    var maxInitialRadius = 0.0;
    var maxScale = double.infinity;
    for (final q in polygon) {
      final dx = q.x - center.x;
      final dy = q.y - center.y;
      final r = math.sqrt(dx * dx + dy * dy);
      if (r > maxInitialRadius) maxInitialRadius = r;

      if (dx > 1e-9) {
        maxScale = math.min(maxScale, (ox + wm - center.x) / dx);
      } else if (dx < -1e-9) {
        maxScale = math.min(maxScale, (ox - center.x) / dx);
      }
      if (dy > 1e-9) {
        maxScale = math.min(maxScale, (oy + hm - center.y) / dy);
      } else if (dy < -1e-9) {
        maxScale = math.min(maxScale, (oy - center.y) / dy);
      }
    }

    if (maxInitialRadius <= 1e-9 || !maxScale.isFinite || maxScale <= 0) {
      return List<MapPoint>.from(polygon);
    }

    final minScale = math.min(1.0, minRadiusMeters / maxInitialRadius);
    final effectiveMin = math.min(minScale, maxScale);
    final scale = rawScale.clamp(effectiveMin, maxScale);

    return polygon
        .map(
          (q) => MapPoint(
            x: center.x + (q.x - center.x) * scale,
            y: center.y + (q.y - center.y) * scale,
          ),
        )
        .toList();
  }

  static double _distance(MapPoint a, MapPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
