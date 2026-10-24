import 'package:flutter/material.dart';

import '../models/cleaning_zone.dart';
import '../models/map_config.dart';
import '../models/map_geometry.dart';

class MapSelectionController {
  List<MapPoint> points = <MapPoint>[];
  Offset? selectionStart;
  int? activeHandleIndex;

  bool get hasSelection => points.length >= CleaningZoneMission.minPoints;

  void clear() {
    points = <MapPoint>[];
    selectionStart = null;
    activeHandleIndex = null;
  }

  int? hitHandle(Offset localPosition, Size size, [MapConfig? config]) {
    if (points.length < CleaningZoneMission.minPoints) return null;

    for (int i = 0; i < points.length; i++) {
      final point = MapGeometry.toScreenPoint(points[i], size, config);
      if ((point - localPosition).distance < 18) {
        return i;
      }
    }
    return null;
  }

  void updateRectangleSelection(
    Offset start,
    Offset end,
    Size size, [
    MapConfig? config,
  ]) {
    points = MapGeometry.rectangleFrom(start, end, size, config);
  }

  void updatePolygonFromPath(
    List<Offset> path,
    Size size, [
    MapConfig? config,
  ]) {
    final polygon = MapGeometry.polygonFromPath(path, size, config);
    if (polygon != null) {
      points = polygon;
    }
  }
}
