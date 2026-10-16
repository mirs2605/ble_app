import 'package:flutter/material.dart';

import '../models/send_button_state.dart';
import '../theme/app_strings.dart';
import '../theme/pill_style.dart';
import 'frosted_glass.dart';
import 'mission_send_button.dart';

class MapSelectionActions extends StatelessWidget {
  final bool showClear;
  final bool showSend;
  final bool canSend;
  final VoidCallback onClear;
  final VoidCallback onSend;
  final SendButtonState sendButtonState;

  /// 開始地点モード切替ボタンを出すか（地図タブでは常時）。
  final bool showPoseMode;

  /// 開始地点モード中か。true時はクリア・送信がpose用になる。
  final bool poseModeActive;
  final VoidCallback? onPoseMode;
  final String clearTooltip;

  const MapSelectionActions({
    super.key,
    required this.showClear,
    required this.showSend,
    required this.canSend,
    required this.onClear,
    required this.onSend,
    this.sendButtonState = SendButtonState.ready,
    this.showPoseMode = false,
    this.poseModeActive = false,
    this.onPoseMode,
    this.clearTooltip = AppStrings.clearTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final clearStyle = PillStyles.destructive();
    final poseStyle = PillStyles.destructive();
    return SafeArea(
      child: Stack(
        children: [
          if (showClear)
            Align(
              alignment: Alignment.bottomLeft,
                child: Padding(
                padding: const EdgeInsets.all(16),
                child: FrostedGlass(
                  gradient: clearStyle.gradient,
                  borderRadius: clearStyle.borderRadius,
                  border: Border.fromBorderSide(
                    BorderSide(color: clearStyle.borderColor, width: 1),
                  ),
                  child: FloatingActionButton(
                    heroTag: 'clear-selection',
                    onPressed: onClear,
                    tooltip: clearTooltip,
                    backgroundColor: Colors.transparent,
                    foregroundColor: clearStyle.foreground,
                    elevation: 0,
                    child: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),
          if (showPoseMode)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FrostedGlass(
                  gradient: poseStyle.gradient,
                  borderRadius: poseStyle.borderRadius,
                  border: Border.fromBorderSide(
                    BorderSide(color: poseStyle.borderColor, width: 1),
                  ),
                  child: FloatingActionButton(
                    heroTag: 'pose-mode',
                    onPressed: onPoseMode,
                    tooltip: poseModeActive
                        ? AppStrings.poseModeExitTooltip
                        : AppStrings.poseModeTooltip,
                    backgroundColor: Colors.transparent,
                    foregroundColor: poseStyle.foreground,
                    elevation: 0,
                    child: Icon(
                      poseModeActive ? Icons.close : Icons.my_location,
                    ),
                  ),
                ),
              ),
            ),
          if (showSend)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MissionSendButton(
                  heroTag: 'send-mission',
                  enabled: canSend,
                  onPressed: onSend,
                  state: sendButtonState,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
