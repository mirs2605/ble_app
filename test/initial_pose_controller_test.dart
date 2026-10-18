import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/services/initial_pose_controller.dart';

void main() {
  test('右ドラッグはyaw=0になる', () {
    const size = Size(300, 200);
    final yaw = InitialPoseController.yawFromLocalDrag(
      const Offset(100, 100),
      const Offset(200, 100),
      size,
    );
    expect(yaw, closeTo(0.0, 1e-9));
  });

  test('画面下方向のドラッグはyaw=-90°になる（地図Y反転）', () {
    const size = Size(300, 200);
    final yaw = InitialPoseController.yawFromLocalDrag(
      const Offset(100, 100),
      const Offset(100, 200),
      size,
    );
    expect(yaw, closeTo(-math.pi / 2, 1e-9));
  });

  test('画面左ドラッグはyaw=180°になる', () {
    const size = Size(300, 200);
    final yaw = InitialPoseController.yawFromLocalDrag(
      const Offset(200, 100),
      const Offset(100, 100),
      size,
    );
    expect(yaw.abs(), closeTo(math.pi, 1e-9));
  });

  test('短いドラッグは無効になる', () {
    expect(
      InitialPoseController.isDragValid(
        const Offset(100, 100),
        const Offset(110, 100),
      ),
      isFalse,
    );
    expect(
      InitialPoseController.isDragValid(
        const Offset(100, 100),
        const Offset(200, 100),
      ),
      isTrue,
    );
  });

  test('しきい値は24pxである', () {
    expect(InitialPoseController.minDragDistance, 24.0);
  });
}
