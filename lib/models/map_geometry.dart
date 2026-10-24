import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cleaning_zone.dart';
import 'map_config.dart';

class MapGeometry {
  static const int freehandPolygonVertexCount = 6;

  /// デフォルトマップ定数（widget_testおよびMapConfig未渡し時の後方互換用）。
  static const double resolution = BuiltinMaps.gakuseigenkanResolution;
  static const double originX = BuiltinMaps.gakuseigenkanOriginX;
  static const double originY = BuiltinMaps.gakuseigenkanOriginY;
  static const double imageWidth = BuiltinMaps.gakuseigenkanImageWidth;
  static const double imageHeight = BuiltinMaps.gakuseigenkanImageHeight;
  static const double widthMeters = imageWidth * resolution;
  static const double heightMeters = imageHeight * resolution;
  static const double imageAspectRatio = imageWidth / imageHeight;

  static double computeMapHeight(double width, [MapConfig? config]) {
    final aspect = config?.aspectRatio ?? imageAspectRatio;
    return width / aspect;
  }

  /// Returns the largest map rectangle that fits without changing the image
  /// aspect ratio.
  static Size fitWithin(Size available, [MapConfig? config]) {
    if (available.width <= 0 || available.height <= 0) {
      return Size.zero;
    }
    final aspect = config?.aspectRatio ?? imageAspectRatio;
    final widthFromHeight = available.height * aspect;
    if (widthFromHeight <= available.width) {
      return Size(widthFromHeight, available.height);
    }
    return Size(available.width, available.width / aspect);
  }

  static Offset toScreenPoint(MapPoint point, Size size, [MapConfig? config]) {
    final ox = config?.originX ?? originX;
    final oy = config?.originY ?? originY;
    final wm = config?.widthMeters ?? widthMeters;
    final hm = config?.heightMeters ?? heightMeters;
    final x = ((point.x - ox) / wm) * size.width;
    final y = size.height - ((point.y - oy) / hm) * size.height;
    return Offset(x, y);
  }

  static MapPoint fromLocal(
    Offset localPosition,
    Size size, [
    MapConfig? config,
  ]) {
    final ox = config?.originX ?? originX;
    final oy = config?.originY ?? originY;
    final wm = config?.widthMeters ?? widthMeters;
    final hm = config?.heightMeters ?? heightMeters;
    final xRatio = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final yRatio = (localPosition.dy / size.height).clamp(0.0, 1.0);
    final x = ox + xRatio * wm;
    final y = oy + (1.0 - yRatio) * hm;
    return MapPoint(x: x, y: y);
  }

  static List<MapPoint> rectangleFrom(
    Offset start,
    Offset end,
    Size size, [
    MapConfig? config,
  ]) {
    final left = start.dx < end.dx ? start.dx : end.dx;
    final right = start.dx < end.dx ? end.dx : start.dx;
    final top = start.dy < end.dy ? start.dy : end.dy;
    final bottom = start.dy < end.dy ? end.dy : start.dy;

    return [
      fromLocal(Offset(left, top), size, config),
      fromLocal(Offset(right, top), size, config),
      fromLocal(Offset(right, bottom), size, config),
      fromLocal(Offset(left, bottom), size, config),
    ];
  }

  static List<MapPoint>? polygonFromPath(
    List<Offset> path,
    Size size, [
    MapConfig? config,
  ]) {
    if (path.length < 2) return null;
    const circumscriptionScale = 1.05;

    final center =
        path.fold<Offset>(Offset.zero, (sum, point) => sum + point) /
        path.length.toDouble();
    final sectors = List<Offset?>.filled(freehandPolygonVertexCount, null);
    final sectorDistances = List<double>.filled(freehandPolygonVertexCount, -1);
    final sectorAngle = math.pi * 2 / freehandPolygonVertexCount;

    for (final point in path) {
      final angle = math.atan2(point.dy - center.dy, point.dx - center.dx);
      final normalizedAngle = (angle + math.pi * 2) % (math.pi * 2);
      final sector = (normalizedAngle / sectorAngle).floor().clamp(
        0,
        freehandPolygonVertexCount - 1,
      );
      final distance = (point - center).distanceSquared;
      if (distance > sectorDistances[sector]) {
        sectors[sector] = point;
        sectorDistances[sector] = distance;
      }
    }

    final vertices = <Offset>[...sectors.whereType<Offset>()];
    if (vertices.length < freehandPolygonVertexCount ||
        vertices.map((point) => (point - center).distance).reduce(math.min) <
            4) {
      return null;
    }

    vertices.sort((a, b) {
      final angleA = math.atan2(a.dy - center.dy, a.dx - center.dx);
      final angleB = math.atan2(b.dy - center.dy, b.dx - center.dx);
      return angleA.compareTo(angleB);
    });
    return vertices
        .map(
          (point) => fromLocal(
            center + (point - center) * circumscriptionScale,
            size,
            config,
          ),
        )
        .toList();
  }
}
