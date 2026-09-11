import 'package:flutter/material.dart';

import '../models/send_button_state.dart';
import 'mission_send_button.dart';

class BottomSendAction extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final String heroTag;
  final SendButtonState state;

  const BottomSendAction({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.heroTag,
    this.state = SendButtonState.ready,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MissionSendButton(
            heroTag: heroTag,
            enabled: enabled,
            onPressed: onPressed,
            state: state,
          ),
        ),
      ),
    );
  }
}
