import 'dart:ui';

import 'package:flutter/material.dart';

import 'ble_status_indicator.dart';
import '../theme/app_colors.dart';

class IconTabNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const IconTabNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.neutral, width: 1),
              borderRadius: BorderRadius.circular(28),
              color: Colors.white.withValues(alpha: 0.35),
            ),
            child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: onTap,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconSize: 28,
                selectedItemColor: AppColors.onColor,
                unselectedItemColor: AppColors.onColor,
                selectedIconTheme: IconThemeData(
                  size: 29,
                  color: AppColors.action,
                ),
                unselectedIconTheme: const IconThemeData(
                  size: 28,
                  color: AppColors.onColor,
                ),
                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                selectedFontSize: 12,
                unselectedFontSize: 12,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.layers_outlined),
                    activeIcon: SelectedTabIcon(icon: Icons.layers),
                    label: '地図',
                    tooltip: '地図',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    activeIcon: SelectedTabIcon(icon: Icons.map),
                    label: 'マップ',
                    tooltip: 'マップ',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.event_note_outlined),
                    activeIcon: SelectedTabIcon(icon: Icons.event_note),
                    label: '予定',
                    tooltip: '予定',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.list_alt_outlined),
                    activeIcon: SelectedTabIcon(icon: Icons.list_alt),
                    label: 'ログ',
                    tooltip: 'ログ',
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }
}