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

  bool get isSelectionComplete => _points.length >= vertexCount;

  bool get isDrawing => selectionStart != null;

  bool get isDraggingHandle => activeHandleIndex != null && hasSelection;

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

  void cancelGesture() {
    selectionStart = null;
    activeHandleIndex = null;
  }

  /// 単一ポインタの操作開始。ハンドル掴みまたは新規フリーハンド描画を開始したら true。
  bool startGesture(Offset localPosition, Size size, [MapConfig? config]) {
    final hit = hitHandle(localPosition, size, config);
    if (isSelectionComplete) {
      if (hit == null) return false;
      activeHandleIndex = hit;
      return true;
    }
    selectionStart = localPosition;
    activeHandleIndex = null;
    return true;
  }

  /// 掴んでいるハンドルを [localPosition] へ移動する。移動したら true。
  bool moveActiveHandle(Offset localPosition, Size size, [MapConfig? config]) {
    if (!isDraggingHandle) return false;
    final next = List<MapPoint>.from(_points);
    next[activeHandleIndex!] = MapGeometry.fromLocal(
      localPosition,
      size,
      config,
    );
    points = next;
    return true;
  }

  /// ジェスチャー終了時にフリーハンド軌跡を確定する。
  /// 新規にフリーハンドで範囲が確定したとき true を返す。
  bool finishGesture(
    List<Offset> freehandPath,
    Size size, {
    MapConfig? config,
    required bool wasTransforming,
  }) {
    final wasDrawing = isDrawing;
    final wasHandleDrag = activeHandleIndex != null;
    if (!wasTransforming && wasDrawing) {
      updatePolygonFromPath(freehandPath, size, config);
    }
    final completedFreehand =
        !wasTransforming &&
        !wasHandleDrag &&
        wasDrawing &&
        _points.length == vertexCount;
    cancelGesture();
    return completedFreehand;
  }

  void clear() {
    _points = <MapPoint>[];
    _basePoints = const <MapPoint>[];
    _lastPath = null;
    _lastSize = null;
    _lastConfig = null;
    cancelGesture();
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
