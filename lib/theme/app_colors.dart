import 'package:flutter/material.dart';

/// 色の意味をアプリ全体で統一するための定義。
abstract final class AppColors {
  static const action = Colors.blue;
  static const selection = Colors.blue;
  static const processing = Colors.orange;
  static const success = Colors.green;
  static const completed = success;
  static const danger = Colors.red;
  static const neutral = Colors.grey;
  static const onColor = Colors.white;
  static const logBackground = Colors.black87;
  static const logText = Colors.greenAccent;
}
