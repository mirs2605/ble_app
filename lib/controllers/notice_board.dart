import 'dart:async';

import 'package:flutter/foundation.dart';

/// タイマー生成の差し替え口。テストではFakeタイマーを注入する。
typedef TimerScheduler =
    Timer Function(Duration duration, void Function() callback);

/// 一定時間で自動消去される単一値の保持役。
/// 時限アナウンス（ステータス表示・通知バー）の重複ロジックの集約先。
class NoticeBoard<T extends Object> {
  NoticeBoard({this._onChanged, TimerScheduler? scheduler})
    : _scheduler = scheduler ?? Timer.new;

  final VoidCallback? _onChanged;
  final TimerScheduler _scheduler;
  Timer? _timer;
  T? _value;

  T? get value => _value;

  void _notify() => _onChanged?.call();

  void show(T value, {Duration duration = const Duration(seconds: 3)}) {
    _timer?.cancel();
    _value = value;
    _notify();
    _timer = _scheduler(duration, () {
      _value = null;
      _notify();
    });
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _value = null;
    _notify();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
