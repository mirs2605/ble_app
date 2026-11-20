import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_strings.dart';

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
              selectedIconTheme: const IconThemeData(
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
                  label: AppStrings.mapsTabLabel,
                  tooltip: AppStrings.mapsTabLabel,
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: SelectedTabIcon(icon: Icons.map),
                  label: AppStrings.mapTabLabel,
                  tooltip: AppStrings.mapTabLabel,
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_note_outlined),
                  activeIcon: SelectedTabIcon(icon: Icons.event_note),
                  label: AppStrings.scheduleTabLabel,
                  tooltip: AppStrings.scheduleTabLabel,
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_outlined),
                  activeIcon: SelectedTabIcon(icon: Icons.list_alt),
                  label: AppStrings.logsTabLabel,
                  tooltip: AppStrings.logsTabLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SelectedTabIcon extends StatelessWidget {
  final IconData icon;

  const SelectedTabIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppColors.action, size: 29);
  }
}
