import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/cleaning_zone.dart';
import '../models/map_config.dart';
import '../models/map_geometry.dart';
import '../models/polygon_transform.dart';
import '../models/shape_template.dart';

class MapSelectionController {
  static const double hitTolerance = PolygonTransform.defaultHitTolerance;

  List<MapPoint> _points = <MapPoint>[];
  List<MapPoint> _basePoints = const <MapPoint>[];
  List<Offset>? _lastPath;
  Size? _lastSize;
  MapConfig? _lastConfig;

  bool _isTemplate = false;
  MapPoint? _templateCenter;

  Offset? selectionStart;
  int? activeHandleIndex;
  int? activeEdgeIndex;
  bool isDraggingFace = false;

  Offset? _dragStartLocal;
  List<MapPoint> _dragStartPoints = const <MapPoint>[];
  MapPoint? _dragStartCenter;

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
    _isTemplate = false;
    _templateCenter = null;
    _lastPath = null;
    _lastSize = null;
    _lastConfig = null;
  }

  /// 現在選択されている範囲がひな形（テンプレート）か否か。
  bool get isTemplate => _isTemplate;

  /// テンプレートの中心座標（テンプレート選択時のみ有効）。
  MapPoint? get templateCenter => _templateCenter;

  bool get hasSelection => _points.length >= CleaningZoneMission.minPoints;

  bool get isSelectionComplete => hasSelection;

  bool get isDrawing => selectionStart != null;

  bool get isDraggingHandle => activeHandleIndex != null && hasSelection;

  bool get isDraggingEdge => activeEdgeIndex != null && hasSelection;

  bool get isDraggingSelection =>
      (activeHandleIndex != null ||
          activeEdgeIndex != null ||
          isDraggingFace) &&
      hasSelection;

  /// ドラッグ中に拡大鏡を表示すべきか（任意多角形の単一頂点移動時のみ true）。
  bool get showsMagnifier => isDraggingHandle && !_isTemplate;

  List<MapPoint> get _activeDragBase =>
      _dragStartPoints.length == _points.length ? _dragStartPoints : _points;

  MapPoint _resolveCenter(List<MapPoint> base) =>
      _dragStartCenter ??
      _templateCenter ??
      PolygonTransform.boundingCenter(base);

  void _commitEditedPoints(List<MapPoint> next) {
    final copy = List<MapPoint>.from(next);
    _points = copy;
    _basePoints = List<MapPoint>.unmodifiable(copy);
    _lastPath = null;
    _lastSize = null;
    _lastConfig = null;
  }

  void _beginDrag(Offset localPosition) {
    _dragStartLocal = localPosition;
    _dragStartPoints = List<MapPoint>.unmodifiable(_points);
    _dragStartCenter = _templateCenter;
  }

  /// ひな形を地図中央に配置し、テンプレート編集モードにする。
  void applyTemplate(ShapeTemplate template, [MapConfig? config]) {
    vertexCount = template.vertexCount;
    final placed = template.placeOn(config);
    _points = List<MapPoint>.from(placed);
    _basePoints = List<MapPoint>.unmodifiable(placed);
    _isTemplate = true;
    _templateCenter = ShapeTemplate.centerOn(config);
    _lastPath = null;
    _lastSize = null;
    _lastConfig = null;
    cancelGesture();
  }

  /// 頂点数を変更する。すでに範囲が選択されていれば、その範囲の頂点数も更新する。
  void setVertexCount(int count) {
    final next = count.clamp(
      MapGeometry.minFreehandVertexCount,
      MapGeometry.maxFreehandVertexCount,
    );
    vertexCount = next;
    if (!hasSelection) return;
    if (_isTemplate && _points.length == next) return;

    _isTemplate = false;
    _templateCenter = null;

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
    activeEdgeIndex = null;
    isDraggingFace = false;
    _dragStartLocal = null;
    _dragStartPoints = const <MapPoint>[];
    _dragStartCenter = null;
  }

  /// 単一ポインタの操作開始。ハンドル・辺・面の掴み、または新規フリーハンド描画を開始したら true。
  bool startGesture(Offset localPosition, Size size, [MapConfig? config]) {
    cancelGesture();
    if (isSelectionComplete) {
      final handleHit = hitHandle(localPosition, size, config);
      if (handleHit != null) {
        activeHandleIndex = handleHit;
        _beginDrag(localPosition);
        return true;
      }
      if (!_isTemplate) {
        final edgeHit = hitEdge(localPosition, size, config);
        if (edgeHit != null) {
          activeEdgeIndex = edgeHit;
          _beginDrag(localPosition);
          return true;
        }
      }
      if (hitPolygon(localPosition, size, config) ||
          (_isTemplate && hitEdge(localPosition, size, config) != null)) {
        isDraggingFace = true;
        _beginDrag(localPosition);
        return true;
      }
      return false;
    }
    selectionStart = localPosition;
    return true;
  }

  /// 掴んでいるハンドルを [localPosition] へ移動する。
  /// テンプレート選択時は中心基準の拡大縮小、任意の多角形では1頂点の移動を行う。
  bool moveActiveHandle(Offset localPosition, Size size, [MapConfig? config]) {
    if (!isDraggingHandle) return false;
    if (_isTemplate) {
      final base = _activeDragBase;
      final scaled = PolygonTransform.scaleFromHandleDrag(
        polygon: base,
        center: _resolveCenter(base),
        handleIndex: activeHandleIndex!,
        startLocal: _dragStartLocal,
        currentLocal: localPosition,
        size: size,
        config: config,
      );
      _commitEditedPoints(scaled);
      return true;
    }

    _commitEditedPoints(
      PolygonTransform.moveVertex(
        _points,
        activeHandleIndex!,
        localPosition,
        size,
        config,
      ),
    );
    return true;
  }

  /// 掴んでいる辺を [localPosition] へ平行移動する（両端の2頂点が同じ量だけ移動）。
  bool moveActiveEdge(Offset localPosition, Size size, [MapConfig? config]) {
    if (!isDraggingEdge) return false;
    final startLocal = _dragStartLocal ?? localPosition;
    _commitEditedPoints(
      PolygonTransform.translateEdgeByScreenDelta(
        _activeDragBase,
        activeEdgeIndex!,
        localPosition - startLocal,
        size,
        config,
      ),
    );
    return true;
  }

  /// 掴んでいる面全体を [localPosition] へ平行移動する。
  bool moveActiveFace(Offset localPosition, Size size, [MapConfig? config]) {
    if (!isDraggingFace || !hasSelection) return false;
    final base = _activeDragBase;
    final startLocal = _dragStartLocal ?? localPosition;
    final result = PolygonTransform.translateFaceByScreenDelta(
      base,
      localPosition - startLocal,
      size,
      config,
    );
    if (_isTemplate) {
      final baseCenter = _resolveCenter(base);
      _templateCenter = MapPoint(
        x: baseCenter.x + result.appliedDelta.dx,
        y: baseCenter.y + result.appliedDelta.dy,
      );
    }
    _commitEditedPoints(result.points);
    return true;
  }

  /// 掴んでいる要素（ハンドル・辺・面）を [localPosition] へ移動する。
  bool moveActiveSelection(
    Offset localPosition,
    Size size, [
    MapConfig? config,
  ]) {
    if (isDraggingHandle) return moveActiveHandle(localPosition, size, config);
    if (isDraggingEdge) return moveActiveEdge(localPosition, size, config);
    if (isDraggingFace) return moveActiveFace(localPosition, size, config);
    return false;
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
    final wasEditing = isDraggingSelection;
    if (!wasTransforming && wasDrawing) {
      updatePolygonFromPath(freehandPath, size, config);
    }
    final completedFreehand =
        !wasTransforming &&
        !wasEditing &&
        wasDrawing &&
        _points.length == vertexCount;
    cancelGesture();
    return completedFreehand;
  }

  void clear() {
    _points = <MapPoint>[];
    _basePoints = const <MapPoint>[];
    _isTemplate = false;
    _templateCenter = null;
    _lastPath = null;
    _lastSize = null;
    _lastConfig = null;
    cancelGesture();
  }

  int? hitHandle(Offset localPosition, Size size, [MapConfig? config]) =>
      PolygonTransform.hitVertex(
        _points,
        localPosition,
        size,
        config: config,
        tolerance: hitTolerance,
      );

  /// [localPosition] の近くにある辺のインデックス（始点頂点のインデックス）を返す。
  int? hitEdge(Offset localPosition, Size size, [MapConfig? config]) =>
      PolygonTransform.hitEdge(
        _points,
        localPosition,
        size,
        config: config,
        tolerance: hitTolerance,
      );

  /// [localPosition] が現在の多角形内部にあるか判定する。
  bool hitPolygon(Offset localPosition, Size size, [MapConfig? config]) =>
      PolygonTransform.containsScreenPoint(_points, localPosition, size, config);

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
      _isTemplate = false;
      _templateCenter = null;
      _lastPath = List<Offset>.unmodifiable(path);
      _lastSize = size;
      _lastConfig = config;
    }
  }
}
