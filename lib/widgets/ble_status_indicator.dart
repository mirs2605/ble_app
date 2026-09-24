import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_strings.dart';
import '../theme/pill_style.dart';
import 'frosted_glass.dart';

/// Bluetooth接続状態の表示。見た目（グラデーション・状態アイコン）は
/// 自前で持たず、外から注入された解決関数で決める。
/// 既定は [PillStyles.forBleStatus]。
class BleStatusIndicator extends StatefulWidget {
  final BleStatus status;
  final String? announcement;
  final IconData? announcementIcon;
  final VoidCallback? onPressed;

  /// 状態から (見た目, 状態アイコン) を返す関数。テストやテーマ差し替え用。
  final (PillStyle, IconData) Function(BleStatus) styleResolver;

  /// タップヒント文言。
  final String tooltipMessage;

  const BleStatusIndicator({
    super.key,
    required this.status,
    this.announcement,
    this.announcementIcon,
    this.onPressed,
    this.styleResolver = PillStyles.forBleStatus,
    this.tooltipMessage = AppStrings.showBluetoothStatus,
  });

  @override
  State<BleStatusIndicator> createState() => _BleStatusIndicatorState();
}

class _BleStatusIndicatorState extends State<BleStatusIndicator>
    with SingleTickerProviderStateMixin {
  /// 光学補正: 白抜きインクの重心が44px円の中心より実測で
  /// (+0.8px, +0.9px) 右下に寄るため、打ち消し方向へずらして
  /// 視覚的な中心に合わせる（レイアウト上の配置は中央揃えのまま）。
  static const _iconOpticalCorrection = Offset(-0.8, -0.9);

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
    final (style, statusIcon) = widget.styleResolver(widget.status);
    final icon = widget.announcementIcon ?? statusIcon;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: message == null ? 44 : 132,
      height: 44,
      child: FrostedGlass(
        gradient: style.gradient,
        borderRadius: style.borderRadius,
        border: Border.fromBorderSide(
          BorderSide(color: style.borderColor, width: 1),
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
                              style: TextStyle(
                                color: style.foreground,
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
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onPressed,
                  customBorder: const CircleBorder(),
                  child: Tooltip(
                    message: widget.tooltipMessage,
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
                        child: Transform.translate(
                          offset: _iconOpticalCorrection,
                          child: Icon(icon, color: style.foreground, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class SelectedTabIcon extends StatelessWidget {
  final IconData icon;

  const SelectedTabIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppColors.action, size: 29);
  }
}
