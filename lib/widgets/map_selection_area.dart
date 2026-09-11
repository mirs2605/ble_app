import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/cleaning_zone.dart';
import '../models/map_geometry.dart';
import '../services/map_selection_controller.dart';

class MapSelectionArea extends StatefulWidget {
  final List<MapPoint> points;
  final ValueChanged<List<MapPoint>> onChanged;
  final ValueChanged<String>? onLog;
  final bool sendCompleted;

  const MapSelectionArea({
    super.key,
    required this.points,
    required this.onChanged,
    this.onLog,
    this.sendCompleted = false,
  });

  @override
  State<MapSelectionArea> createState() => _MapSelectionAreaState();
}

class _MapSelectionAreaState extends State<MapSelectionArea> {
  final MapSelectionController _selectionController = MapSelectionController();
  final TransformationController _mapTransformController =
      TransformationController();
  Offset? _lastFocalPoint;
  double _lastScale = 1.0;
  bool _wasTransforming = false;
  final List<Offset> _freehandPath = [];
  Offset? _magnifierPosition;

  @override
  void initState() {
    super.initState();
    _selectionController.points = List<MapPoint>.from(widget.points);
  }

  @override
  void didUpdateWidget(covariant MapSelectionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.points, widget.points)) {
      _selectionController.points = List<MapPoint>.from(widget.points);
    }
  }

  @override
  void dispose() {
    _mapTransformController.dispose();
    super.dispose();
  }

  void _emitSelection() {
    widget.onChanged(List<MapPoint>.from(_selectionController.points));
  }

  Offset _toLocalMapPoint(Offset pointer, Size size, Offset mapOffset) {
    final inverse = vm.Matrix4.inverted(_mapTransformController.value);
    final local = inverse.transform3(vm.Vector3(pointer.dx, pointer.dy, 0));
    return Offset(
      (local.x - mapOffset.dx).clamp(0.0, size.width),
      (local.y - mapOffset.dy).clamp(0.0, size.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = Size(
          constraints.maxWidth,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MapGeometry.computeMapHeight(constraints.maxWidth),
        );
        final mapSize = MapGeometry.fitWithin(availableSize);

        final mapOffset = Offset(
          (availableSize.width - mapSize.width) / 2,
          (availableSize.height - mapSize.height) / 2,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _lastFocalPoint = details.localFocalPoint;
            _lastScale = 1.0;
            if (details.pointerCount > 1) {
              _selectionController.selectionStart = null;
              _selectionController.activeHandleIndex = null;
              _freehandPath.clear();
            } else {
              final local = _toLocalMapPoint(
                details.localFocalPoint,
                mapSize,
                mapOffset,
              );
              final hit = _selectionController.hitHandle(local, mapSize);
              if (_selectionController.points.length >= 4) {
                if (hit != null) {
                  setState(() {
                    _selectionController.activeHandleIndex = hit;
                    _magnifierPosition = details.localFocalPoint;
                  });
                }
                return;
              }
              setState(() {
                _selectionController.selectionStart = local;
                _selectionController.activeHandleIndex = null;
                _freehandPath
                  ..clear()
                  ..add(local);
              });
            }
          },
          onScaleUpdate: (details) {
            final previousFocal = _lastFocalPoint ?? details.localFocalPoint;
            final focalDelta = details.localFocalPoint - previousFocal;
            _lastFocalPoint = details.localFocalPoint;

            if (details.pointerCount > 1) {
              _wasTransforming = true;
              final scaleDelta = details.scale / _lastScale;
              _lastScale = details.scale;
              final next = vm.Matrix4.identity()
                ..translateByDouble(
                  details.localFocalPoint.dx,
                  details.localFocalPoint.dy,
                  0,
                  1,
                )
                ..scaleByDouble(scaleDelta, scaleDelta, 1, 1)
                ..translateByDouble(
                  -details.localFocalPoint.dx,
                  -details.localFocalPoint.dy,
                  0,
                  1,
                )
                ..translateByDouble(focalDelta.dx, focalDelta.dy, 0, 1)
                ..multiply(_mapTransformController.value);
              final currentScale = next.getMaxScaleOnAxis();
              if (currentScale >= 1.0 && currentScale <= 4.0) {
                setState(() => _mapTransformController.value = next);
              }
              return;
            }

            final local = _toLocalMapPoint(
              details.localFocalPoint,
              mapSize,
              mapOffset,
            );
            if (_selectionController.activeHandleIndex != null &&
                _selectionController.points.length == 4) {
              final next = List<MapPoint>.from(_selectionController.points);
              next[_selectionController.activeHandleIndex!] =
                  MapGeometry.fromLocal(local, mapSize);
              setState(() {
                _selectionController.points = next;
                _magnifierPosition = details.localFocalPoint;
                _emitSelection();
              });
              return;
            }
            if (_selectionController.selectionStart != null &&
                _selectionController.points.length < 4) {
              setState(() => _freehandPath.add(local));
            }
          },
          onScaleEnd: (_) {
            _lastFocalPoint = null;
            _lastScale = 1.0;
            final wasTransforming = _wasTransforming;
            _wasTransforming = false;
            final wasDrawing = _selectionController.selectionStart != null;
            setState(() {
              if (!wasTransforming && wasDrawing) {
                _selectionController.updateRectangleFromPath(
                  _freehandPath,
                  mapSize,
                );
              }
              _selectionController.selectionStart = null;
              if (!wasTransforming &&
                  _selectionController.points.length == 4 &&
                  _selectionController.activeHandleIndex == null) {
                widget.onLog?.call('🖐️ 四角形を選択しました');
              }
              _selectionController.activeHandleIndex = null;
              _freehandPath.clear();
              _magnifierPosition = null;
            });
            if (!wasTransforming && wasDrawing) {
              _emitSelection();
            }
          },
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                SizedBox(
                  width: availableSize.width,
                  height: availableSize.height,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: _mapTransformController.value,
                    child: Stack(
                      children: [
                        Positioned(
                          left: mapOffset.dx,
                          top: mapOffset.dy,
                          width: mapSize.width,
                          height: mapSize.height,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/maps/rouka7.png',
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _MapSelectionPainter(
                                      _selectionController.points,
                                      sendCompleted: widget.sendCompleted,
                                      activeHandle: _selectionController
                                          .activeHandleIndex,
                                      freehandPath: List<Offset>.from(
                                        _freehandPath,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectionController.points.isEmpty &&
                    _freehandPath.isEmpty)
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('範囲を囲ってください'),
                      ),
                    ),
                  ),
                if (_selectionController.activeHandleIndex != null &&
                    _magnifierPosition != null)
                  _MapMagnifier(
                    position: _magnifierPosition!,
                    viewportSize: availableSize,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapMagnifier extends StatelessWidget {
  static const double diameter = 116;
  static const double gap = 48;

  final Offset position;
  final Size viewportSize;

  const _MapMagnifier({required this.position, required this.viewportSize});

  @override
  Widget build(BuildContext context) {
    final left = (position.dx - diameter / 2)
        .clamp(0.0, viewportSize.width - diameter)
        .toDouble();
    final top = (position.dy - diameter - gap)
        .clamp(0.0, viewportSize.height - diameter)
        .toDouble();
    final lensCenter = Offset(left + diameter / 2, top + diameter / 2);

    return Positioned(
      left: left,
      top: top,
      width: diameter,
      height: diameter,
      child: IgnorePointer(
        child: RawMagnifier(
          size: const Size(diameter, diameter),
          magnificationScale: 1.8,
          focalPointOffset: Offset(
            position.dx - lensCenter.dx,
            position.dy - lensCenter.dy,
          ),
          clipBehavior: Clip.hardEdge,
          decoration: MagnifierDecoration(
            opacity: 1,
            shape: CircleBorder(
              side: BorderSide(color: Colors.white, width: 3),
            ),
            shadows: [BoxShadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

class _MapSelectionPainter extends CustomPainter {
  final List<MapPoint> points;
  final bool sendCompleted;
  final int? activeHandle;
  final List<Offset> freehandPath;

  const _MapSelectionPainter(
    this.points, {
    this.sendCompleted = false,
    this.activeHandle,
    this.freehandPath = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (freehandPath.length >= 2) {
      final path = Path()..moveTo(freehandPath.first.dx, freehandPath.first.dy);
      for (final point in freehandPath.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.green.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (points.length < 2) return;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final point = MapGeometry.toScreenPoint(points[i], size);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }

    }
    if (points.length >= 3) path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = sendCompleted ? Colors.blue : Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (int i = 0; i < points.length; i++) {
      final point = MapGeometry.toScreenPoint(points[i], size);
      final radius = i == activeHandle ? 7.0 : 5.0;
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = i == activeHandle
              ? Colors.red
              : sendCompleted
              ? Colors.blue
              : Colors.green,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapSelectionPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.sendCompleted != sendCompleted ||
      oldDelegate.activeHandle != activeHandle ||
      oldDelegate.freehandPath != freehandPath;
}
