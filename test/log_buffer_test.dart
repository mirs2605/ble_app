import 'package:flutter_test/flutter_test.dart';
import 'package:mirs_ble_app/controllers/log_buffer.dart';

void main() {
  test('タイムスタンプ付きで先頭に追加し、trim指定時は上限で切り詰める', () {
    final buffer = LogBuffer(
      maxEntries: 3,
      now: () => DateTime(2026, 11, 13, 9, 5, 7),
    );

    buffer.add('first');
    buffer.add('second');
    buffer.add('third');
    buffer.add('fourth', trim: true);

    expect(buffer.entries, [
      '[09:05:07] fourth',
      '[09:05:07] third',
      '[09:05:07] second',
    ]);
  });
}
