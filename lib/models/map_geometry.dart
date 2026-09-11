import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cleaning_zone.dart';

class MapGeometry {
  static const double resolution = 0.1;
  static const double originX = -25.8;
  static const double originY = -73.9;
  static const double imageWidth = 561.0;
  static const double imageHeight = 775.0;
  static const double widthMeters = imageWidth * resolution;
  static const double heightMeters = imageHeight * resolution;
  static const double imageAspectRatio = imageWidth / imageHeight;

  static double computeMapHeight(double width) => width / imageAspectRatio;

  /// Returns the largest map rectangle that fits without changing the image
  /// aspect ratio.
  static Size fitWithin(Size available) {
    if (available.width <= 0 || available.height <= 0) {
      return Size.zero;
    }

    final widthFromHeight = available.height * imageAspectRatio;
    if (widthFromHeight <= available.width) {
      return Size(widthFromHeight, available.height);
    }
    return Size(available.width, computeMapHeight(available.width));
  }

  static Offset toScreenPoint(MapPoint point, Size size) {
    final x = ((point.x - originX) / widthMeters) * size.width;
    final y = size.height - ((point.y - originY) / heightMeters) * size.height;
    return Offset(x, y);
  }

  static MapPoint fromLocal(Offset localPosition, Size size) {
    final xRatio = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final yRatio = (localPosition.dy / size.height).clamp(0.0, 1.0);

    final x = originX + xRatio * widthMeters;
    final y = originY + (1.0 - yRatio) * heightMeters;
    return MapPoint(x: x, y: y);
  }

  static List<MapPoint> rectangleFrom(Offset start, Offset end, Size size) {
    final left = start.dx < end.dx ? start.dx : end.dx;
    final right = start.dx < end.dx ? end.dx : start.dx;
    final top = start.dy < end.dy ? start.dy : end.dy;
    final bottom = start.dy < end.dy ? end.dy : start.dy;

    return [
      fromLocal(Offset(left, top), size),
      fromLocal(Offset(right, top), size),
      fromLocal(Offset(right, bottom), size),
      fromLocal(Offset(left, bottom), size),
    ];
  }

  static List<MapPoint>? rectangleFromPath(List<Offset> path, Size size) {
    if (path.length < 2) return null;
    const circumscriptionScale = 1.05;

    final center =
        path.fold<Offset>(Offset.zero, (sum, point) => sum + point) /
        path.length.toDouble();
    final sectors = List<Offset?>.filled(4, null);
    final sectorDistances = List<double>.filled(4, -1);

    for (final point in path) {
      final angle = math.atan2(point.dy - center.dy, point.dx - center.dx);
      final normalizedAngle = (angle + math.pi * 2) % (math.pi * 2);
      final sector = (normalizedAngle / (math.pi / 2)).floor().clamp(0, 3);
      final distance = (point - center).distanceSquared;
      if (distance > sectorDistances[sector]) {
        sectors[sector] = point;
        sectorDistances[sector] = distance;
      }
    }

    final vertices = <Offset>[...sectors.whereType<Offset>()];
    if (vertices.length < 4 ||
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
          (point) =>
              fromLocal(center + (point - center) * circumscriptionScale, size),
        )
        .toList();
  }
}
