import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mirs_ble_app/controllers/notice_board.dart';

class _FakeTimer implements Timer {
  void Function()? callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;

  void fire() {
    if (!cancelled) callback?.call();
  }
}

void main() {
  test('showで公開され時間経過で消去される', () {
    var changes = 0;
    _FakeTimer? timer;
    final board = NoticeBoard<String>(
      onChanged: () => changes++,
      scheduler: (duration, callback) {
        expect(duration, const Duration(seconds: 3));
        return timer = _FakeTimer()..callback = callback;
      },
    );

    board.show('hello');
    expect(board.value, 'hello');
    expect(changes, 1);

    timer!.fire();
    expect(board.value, isNull);
    expect(changes, 2);
  });

  test('再showで前のタイマーは取り消される', () {
    _FakeTimer? first;
    _FakeTimer? second;
    var calls = 0;
    final board = NoticeBoard<String>(
      scheduler: (duration, callback) {
        calls++;
        final timer = _FakeTimer()..callback = callback;
        if (calls == 1) {
          first = timer;
        } else {
          second = timer;
        }
        return timer;
      },
    );

    board.show('one');
    board.show('two');
    expect(first!.cancelled, isTrue);
    expect(board.value, 'two');

    // 取り消し済みの初回タイマーが発火しても値は消えない。
    first!.fire();
    expect(board.value, 'two');
    second!.fire();
    expect(board.value, isNull);
  });

  test('clearは即時消去しタイマーを取り消す', () {
    var changes = 0;
    _FakeTimer? timer;
    final board = NoticeBoard<String>(
      onChanged: () => changes++,
      scheduler: (duration, callback) =>
          timer = _FakeTimer()..callback = callback,
    );

    board.show('hello');
    board.clear();
    expect(board.value, isNull);
    timer!.fire();
    // clear後の発火では何も起きない（追加通知なし）。
    expect(changes, 2);
  });

  test('dispose後はタイマー発火が無視される', () {
    _FakeTimer? timer;
    final board = NoticeBoard<String>(
      scheduler: (duration, callback) =>
          timer = _FakeTimer()..callback = callback,
    );

    board.show('hello');
    board.dispose();
    timer!.fire();
    expect(board.value, 'hello');
  });
}
