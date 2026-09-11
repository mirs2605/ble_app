import 'package:flutter/material.dart';

import '../models/send_button_state.dart';

class MissionSendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final String heroTag;
  final SendButtonState state;

  const MissionSendButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.heroTag,
    this.state = SendButtonState.ready,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = state != SendButtonState.ready;
    final buttonColor = switch (state) {
      SendButtonState.ready => Colors.blue,
      SendButtonState.sending => Colors.orange,
      SendButtonState.completed => Colors.blue,
    };
    final label = switch (state) {
      SendButtonState.ready => null,
      SendButtonState.sending => '送信中',
      SendButtonState.completed => '送信完了',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: isExpanded ? 132 : 56,
      height: 56,
      child: label == null
          ? FloatingActionButton(
              heroTag: heroTag,
              onPressed: enabled ? onPressed : null,
              tooltip: '送信',
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: const CircleBorder(),
              child: const Icon(Icons.send),
            )
          : FloatingActionButton.extended(
              heroTag: heroTag,
              onPressed: enabled ? onPressed : null,
              tooltip: '送信',
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: StadiumBorder(
                side: BorderSide(color: buttonColor, width: 2),
              ),
              label: Text(label),
              icon: const Icon(Icons.send),
            ),
    );
  }
}
