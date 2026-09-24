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

  const MapSelectionActions({
    super.key,
    required this.showClear,
    required this.showSend,
    required this.canSend,
    required this.onClear,
    required this.onSend,
    this.sendButtonState = SendButtonState.ready,
  });

  @override
  Widget build(BuildContext context) {
    final clearStyle = PillStyles.destructive();
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
                    tooltip: AppStrings.clearTooltip,
                    backgroundColor: Colors.transparent,
                    foregroundColor: clearStyle.foreground,
                    elevation: 0,
                    child: const Icon(Icons.delete_outline),
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
