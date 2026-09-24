import 'package:flutter/material.dart';

import '../models/app_notice.dart';
import '../theme/app_strings.dart';
import '../theme/pill_style.dart';
import 'frosted_glass.dart';

/// Bluetoothステータスアイコンとは無関係な独立した通知バー。
///
/// Bluetoothステータスアイコンの右側に配置されることを想定し、
/// メッセージがあるときだけ上からスライドインして表示し、
/// メッセージが消えるときは上へスライドアウトして非表示になる。
/// 横方向の伸縮は行わない（幅アニメなしの純粋な縦スライド＋フェード）。
///
/// 見た目は常にニュートラルなグレー。深刻度による色分けは行わない。
/// [style] を渡せば差し替え可能。
class StatusNotificationBar extends StatefulWidget {
  /// 表示するメッセージ。null のときは非表示（スライドアウト）になる。
  final String? message;

  /// メッセージの左に表示するアイコン。null のときはアイコンなし。
  final IconData? icon;

  /// 注入される見た目。null のときはニュートラルグレーを使う。
  final PillStyle? style;

  /// アニメーション時間。
  final Duration slideDuration;

  const StatusNotificationBar({
    super.key,
    required this.message,
    this.icon,
    this.style,
    this.slideDuration = const Duration(milliseconds: 350),
  });

  /// [AppNotice] から文言・アイコンを解決するファクトリ。色は常にグレー。
  factory StatusNotificationBar.notice(
    AppNotice? notice, {
    Key? key,
    PillStyle? style,
    Duration slideDuration = const Duration(milliseconds: 350),
  }) {
    return StatusNotificationBar(
      key: key,
      message: notice?.message,
      icon: notice?.icon,
      style: style,
      slideDuration: slideDuration,
    );
  }

  @override
  State<StatusNotificationBar> createState() => _StatusNotificationBarState();
}

class _StatusNotificationBarState extends State<StatusNotificationBar> {
  // 非表示アニメ中に空のバーが出ないよう、最後のメッセージを保持する。
  String? _displayedMessage;
  IconData? _displayedIcon;

  @override
  void initState() {
    super.initState();
    _displayedMessage = widget.message;
    _displayedIcon = widget.icon;
  }

  @override
  void didUpdateWidget(covariant StatusNotificationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != null) {
      _displayedMessage = widget.message;
      _displayedIcon = widget.icon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.message != null;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
      duration: widget.slideDuration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final clamped = t.clamp(0.0, 1.0);
        // 非表示完了時はレイアウトから除外してBTアイコンを端に寄せる。
        if (clamped <= 0.01 && !visible) {
          return const SizedBox.shrink();
        }
        // 上からのスライド量。バー高さ＋余白分だけ上にずらす。
        // 横方向には一切動かさない。
        // 等倍のまま移動させるため幅アニメ・クリップは使わない。
        // （幅をアニメさせると表示時に縮んで見え、
        // クリップするとシャッター状の消え方になるため）
        const slideDistance = 56.0;
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, -slideDistance * (1 - clamped)),
            child: child,
          ),
        );
      },
      child: _BarContent(
        message: _displayedMessage,
        icon: _displayedIcon,
        style: widget.style ?? PillStyles.notification(),
      ),
    );
  }
}

class _BarContent extends StatelessWidget {
  final String? message;
  final IconData? icon;
  final PillStyle style;

  const _BarContent({
    required this.message,
    required this.icon,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      gradient: style.gradient,
      borderRadius: style.borderRadius,
      border: Border.fromBorderSide(
        BorderSide(color: style.borderColor, width: 1),
      ),
      child: Container(
        height: 44,
        // 幅は中身に合わせる。上限は親のFlexible（画面幅の残り）が担い、
        // そこを超えた場合のみ末尾省略する。
        padding: const EdgeInsets.only(
          left: 14,
          right: 14,
          top: 0,
          bottom: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: style.foreground, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  final offset =
                      Tween<Offset>(
                        begin: const Offset(0, -0.6),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: Text(
                  message ?? '',
                  key: ValueKey(message ?? 'empty'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
