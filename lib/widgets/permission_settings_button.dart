import 'package:flutter/material.dart';

class PermissionSettingsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PermissionSettingsButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'permission-settings',
      onPressed: onPressed,
      tooltip: '権限設定を開く',
      child: const Icon(Icons.settings),
    );
  }
}
