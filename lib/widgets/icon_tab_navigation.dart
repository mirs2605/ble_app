import 'package:flutter/material.dart';

import 'ble_status_indicator.dart';

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
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          elevation: 4,
          color: Colors.grey.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 88,
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              iconSize: 28,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.white,
              selectedIconTheme: IconThemeData(
                size: 29,
                color: Colors.blue,
              ),
              unselectedIconTheme: const IconThemeData(
                size: 28,
                color: Colors.white,
              ),
              selectedLabelStyle: const TextStyle(fontSize: 0),
              unselectedLabelStyle: const TextStyle(fontSize: 0),
              selectedFontSize: 0,
              unselectedFontSize: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.tune_outlined),
                  activeIcon: SelectedTabIcon(icon: Icons.tune),
                  label: '',
                  tooltip: '数値',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: SelectedTabIcon(icon: Icons.map),
                  label: '',
                  tooltip: 'マップ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_outlined),
                  activeIcon: SelectedTabIcon(icon: Icons.list_alt),
                  label: '',
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
