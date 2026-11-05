import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'frosted_glass.dart';

/// 下部タブバー（[IconTabNavigation]）と同じ質感のアイコンボタン。
/// 半透明の白＋ぼかし＋灰色の縁取り。[onPressed] が null のときは見た目だけを描く
/// （PopupMenuButton の child に使うなど、タップを外側で受けるとき）。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 56,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget button = FrostedGlass(
      color: Colors.white.withValues(alpha: 0.35),
      sigma: 12,
      borderRadius: size / 2,
      border: Border.all(color: AppColors.neutral, width: 1),
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, size: 28, color: AppColors.onColor),
          ),
        ),
      ),
    );
    if (tooltip != null && onPressed != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
