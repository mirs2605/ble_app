import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/send_button_state.dart';
import '../theme/app_strings.dart';
import '../theme/pill_style.dart';
import 'frosted_glass.dart';

/// 送信ボタン。常に丸ボタンで、文言表示は通知バーに任せる。
/// 見た目は [PillStyles] から解決し、このWidget内に色のリテラルを持たない。
///
/// - 準備中: 紙飛行機。タップで送信する。
/// - 送信中: リングカーソルのみ。タップを受け付けない。
/// - 完了: 塗りつぶしチェック（遷移時にY軸へ1回転）。
class MissionSendButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final String heroTag;
  final SendButtonState state;

  /// 見た目の解決関数。テストやテーマ差し替え用。
  final PillStyle Function(SendButtonState) styleResolver;

  const MissionSendButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.heroTag,
    this.state = SendButtonState.ready,
    this.styleResolver = PillStyles.forSendState,
  });

  @override
  State<MissionSendButton> createState() => _MissionSendButtonState();
}

class _MissionSendButtonState extends State<MissionSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.state == SendButtonState.completed) {
      _flipController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MissionSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 未完了→完了への遷移でチェックをY軸に1回転させる。
    if (widget.state == SendButtonState.completed &&
        oldWidget.state != SendButtonState.completed) {
      _flipController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.styleResolver(widget.state);
    final isSending = widget.state == SendButtonState.sending;
    final isCompleted = widget.state == SendButtonState.completed;

    return SizedBox(
      width: 56,
      height: 56,
      child: FrostedGlass(
        gradient: style.gradient,
        borderRadius: style.borderRadius,
        border: Border.fromBorderSide(
          BorderSide(color: style.borderColor, width: 1),
        ),
        child: isSending
            ? Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: style.foreground,
                  ),
                ),
              )
            : FloatingActionButton(
                heroTag: widget.heroTag,
                onPressed: widget.enabled ? widget.onPressed : null,
                tooltip: AppStrings.sendTooltip,
                backgroundColor: Colors.transparent,
                foregroundColor: style.foreground,
                elevation: 0,
                shape: const CircleBorder(),
                child: isCompleted
                    ? AnimatedBuilder(
                        animation: _flipController,
                        builder: (_, child) {
                          final angle =
                              _flipController.value * math.pi * 2;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            child: child,
                          );
                        },
                        child: const Icon(Icons.check_circle, size: 26),
                      )
                    : const Icon(Icons.send, size: 26),
              ),
      ),
    );
  }
}
