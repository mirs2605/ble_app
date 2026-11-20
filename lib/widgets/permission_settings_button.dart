import 'package:flutter/material.dart';

import '../theme/app_strings.dart';

class PermissionSettingsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PermissionSettingsButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'permission-settings',
      onPressed: onPressed,
      tooltip: AppStrings.openPermissionSettingsTooltip,
      child: const Icon(Icons.settings),
    );
  }
}
