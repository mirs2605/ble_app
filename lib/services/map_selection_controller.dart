import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/cleaning_zone.dart';
import '../models/map_config.dart';
import '../models/map_geometry.dart';

class MapSelectionController {
  List<MapPoint> _points = <MapPoint>[];
  List<MapPoint> _basePoints = const <MapPoint>[];
  List<Offset>? _lastPath;
  Size? _lastSize;
  MapConfig? _lastConfig;

  Offset? selectionStart;
  int? activeHandleIndex;

  /// フリーハンドで囲んだときに生成する多角形の頂点数。
  int vertexCount = MapGeometry.freehandPolygonVertexCount;

  List<MapPoint> get points => _points;

  set points(List<MapPoint> value) {
    final copy = List<MapPoint>.from(value);
    if (listEquals(_points, copy)) {
      _points = copy;
      return;
    }
    _points = copy;
    _basePoints = List<MapPoint>.unmodifiable(copy);
    _lastPath = null;
    _lastSize = null;
    _lastConfig = null;
  }

  bool get hasSelection => _points.length >= CleaningZoneMission.minPoints;

  /// 頂点数を変更する。すでに範囲が選択されていれば、その範囲の頂点数も更新する。
  void setVertexCount(int count) {
    final next = count.clamp(
      MapGeometry.minFreehandVertexCount,
      MapGeometry.maxFreehandVertexCount,
    );
    vertexCount = next;
    if (!hasSelection) return;

    if (_lastPath != null && _lastSize != null) {
      final polygon = MapGeometry.polygonFromPath(
        _lastPath!,
        _lastSize!,
        _lastConfig,
        next,
      );
      if (polygon != null) {
        _points = polygon;
        _basePoints = List<MapPoint>.unmodifiable(polygon);
        return;
      }
    }

    final base = _basePoints.length >= CleaningZoneMission.minPoints
        ? _basePoints
        : _points;
    _points = MapGeometry.resamplePolygon(base, next);
  }

  void clear() {
    _points = <MapPoint>[];
    _basePoints = const <MapPoint>[];
    _lastPath = null;
    _lastSize = null;
    _lastConfig = null;
    selectionStart = null;
    activeHandleIndex = null;
  }

  int? hitHandle(Offset localPosition, Size size, [MapConfig? config]) {
    if (_points.length < CleaningZoneMission.minPoints) return null;

    for (int i = 0; i < _points.length; i++) {
      final point = MapGeometry.toScreenPoint(_points[i], size, config);
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
    final polygon = MapGeometry.polygonFromPath(
      path,
      size,
      config,
      vertexCount,
    );
    if (polygon != null) {
      _points = polygon;
      _basePoints = List<MapPoint>.unmodifiable(polygon);
      _lastPath = List<Offset>.unmodifiable(path);
      _lastSize = size;
      _lastConfig = config;
    }
  }
}
