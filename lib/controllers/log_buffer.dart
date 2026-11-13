/// 時刻付きログの保持と上限切り詰めを担うバッファ。
///
/// [BleHomeController] からログ整形・件数制限の関心事を分離し、
/// 時刻取得関数 [now] を注入できるようにして単体テストを容易にする。
class LogBuffer {
  LogBuffer({
    this.maxEntries = 100,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxEntries;
  final DateTime Function() _now;
  final List<String> _entries = [];

  List<String> get entries => List.unmodifiable(_entries);

  void add(String message, {bool trim = false}) {
    final time = _now();
    final timestamp =
        '[${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}]';
    _entries.insert(0, '$timestamp $message');
    if (trim && _entries.length > maxEntries) {
      _entries.removeLast();
    }
  }
}
