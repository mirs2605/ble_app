import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/ble_service.dart';

class BleStatusIndicator extends StatefulWidget {
  final BleStatus status;
  final String? announcement;
  final IconData? announcementIcon;
  final VoidCallback? onPressed;

  const BleStatusIndicator({
    super.key,
    required this.status,
    this.announcement,
    this.announcementIcon,
    this.onPressed,
  });

  @override
  State<BleStatusIndicator> createState() => _BleStatusIndicatorState();
}

class _BleStatusIndicatorState extends State<BleStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkRotationController;

  @override
  void initState() {
    super.initState();
    _checkRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _startCheckRotationIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BleStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.announcementIcon != oldWidget.announcementIcon) {
      _startCheckRotationIfNeeded();
    }
  }

  void _startCheckRotationIfNeeded() {
    if (widget.announcementIcon == Icons.check_circle) {
      _checkRotationController
        ..reset()
        ..forward();
    } else {
      _checkRotationController.reset();
    }
  }

  @override
  void dispose() {
    _checkRotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.announcement;
    final (color, statusIcon) = switch (widget.status) {
      BleStatus.idle => (Colors.grey, Icons.bluetooth),
      BleStatus.scanning => (Colors.orange, Icons.bluetooth_searching),
      BleStatus.connecting => (Colors.orange, Icons.bluetooth_searching),
      BleStatus.connected => (Colors.blue, Icons.bluetooth_connected),
      BleStatus.sending => (Colors.green, Icons.bluetooth_connected),
      BleStatus.disconnected => (Colors.grey, Icons.bluetooth_disabled),
      BleStatus.error => (Colors.red, Icons.error),
    };
    final icon = widget.announcementIcon ?? statusIcon;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: message == null ? 44 : 132,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 44),
              child: ClipRect(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        final offset =
                            Tween<Offset>(
                              begin: const Offset(0, -0.8),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            );
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                      child: message == null
                          ? const SizedBox.shrink(key: ValueKey('hidden'))
                          : Text(
                              message,
                              key: ValueKey(message),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: color,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onPressed,
                  customBorder: const CircleBorder(),
                  child: Tooltip(
                    message: 'Bluetoothステータスを表示',
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _checkRotationController,
                        builder: (context, child) {
                          if (icon != Icons.check_circle) return child!;
                          final angle =
                              _checkRotationController.value * math.pi * 2;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            child: child,
                          );
                        },
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectedTabIcon extends StatelessWidget {
  final IconData icon;

  const SelectedTabIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Colors.blue, size: 29);
  }
}
