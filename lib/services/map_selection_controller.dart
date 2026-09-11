import 'package:flutter/material.dart';

import '../models/cleaning_zone.dart';
import '../models/map_geometry.dart';

class MapSelectionController {
  List<MapPoint> points = <MapPoint>[];
  Offset? selectionStart;
  int? activeHandleIndex;

  bool get hasSelection => points.length == 4;

  void clear() {
    points = <MapPoint>[];
    selectionStart = null;
    activeHandleIndex = null;
  }

  int? hitHandle(Offset localPosition, Size size) {
    if (points.length != 4) return null;

    for (int i = 0; i < points.length; i++) {
      final point = MapGeometry.toScreenPoint(points[i], size);
      if ((point - localPosition).distance < 18) {
        return i;
      }
    }
    return null;
  }

  void updateRectangleSelection(Offset start, Offset end, Size size) {
    points = MapGeometry.rectangleFrom(start, end, size);
  }

  void updateRectangleFromPath(List<Offset> path, Size size) {
    final rectangle = MapGeometry.rectangleFromPath(path, size);
    if (rectangle != null) {
      points = rectangle;
    }
  }
}
