import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  final double sigma;
  final double borderRadius;
  final Border border;

  const FrostedGlass({
    super.key,
    required this.child,
    this.color,
    this.gradient,
    this.sigma = 10,
    this.borderRadius = 28,
    this.border = const Border.fromBorderSide(
      BorderSide(color: Colors.white54, width: 1),
    ),
  }) : assert(color != null || gradient != null);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            borderRadius: radius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}