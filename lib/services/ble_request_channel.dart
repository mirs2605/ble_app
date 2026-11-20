import 'dart:convert';

import 'ble_adapter.dart';

/// 1回の要求に対する結果の種類。内容の解釈（ACK か、JSON か）は呼び出し側が行う。
enum BleReplyStatus {
  /// 応答を読めた。[BleReply.bytes] に中身がある。
  received,

  /// 応答特性のないサーバーへ書き込みだけ行った（応答は無い）。
  writtenWithoutResponse,

  /// 接続していない。
  notReady,

  /// 別の要求の途中。
  busy,

  /// 要求が送れる大きさを超えている。
  tooLarge,

  /// 回線の失敗（書き込み・読み取り・送信サイズ取得）。接続は切られる。
  linkFailed,
}

class BleReply {
  final BleReplyStatus status;
  final List<int> bytes;

  const BleReply(this.status, [this.bytes = const []]);

  bool get received => status == BleReplyStatus.received;
}

/// 応答の中身の判定（`ACK` / `NACK`）。
class BleResponse {
  const BleResponse._();

  static bool isAccepted(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false) == 'ACK';
    } on FormatException {
      return false;
    }
  }
}

class BlePayloadChunker {
  const BlePayloadChunker._();

  static List<List<int>> split(List<int> payload, int chunkSize) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize');
    }
    return [
      for (var offset = 0; offset < payload.length; offset += chunkSize)
        payload.sublist(offset, (offset + chunkSize).clamp(0, payload.length)),
    ];
  }
}

/// 運搬役が接続に求める操作。接続の状態を持つのは [BleService] だけで、
/// 運搬役は「使ってよいか」を聞き、送受信の開始・終了と回線の失敗を伝える。
abstract class BleLinkControl {
  bool get isReady;

  /// 要求の送受信を始める（状態を sending にする）。
  void beginTransfer();

  /// 要求の送受信が終わった（回線は生きている）。
  void endTransfer();

  /// 回線が信用できなくなった。接続を切り、再接続できる状態に戻す。
  Future<void> abandonLink();
}

/// 要求1件を運ぶ。JSON を改行区切りで分割して書き込み、応答を読み取る。
///
/// 責任は運搬だけ: 接続の確立はしない（[BleLinkControl] に任せる）。
/// 応答の意味（ACK・JSON）は解釈しない（各プロトコルの担当が解釈する）。
/// 同時に1件しか運ばない。
class BleRequestChannel {
  BleRequestChannel({
    required this._adapter,
    required this._link,
    required void Function(String message) onLog,
  }) : _log = onLog;

  static const responseTimeout = Duration(seconds: 5);
  static const maxPayloadBytes = 4096;

  final BleAdapter _adapter;
  final BleLinkControl _link;
  final void Function(String message) _log;
  bool _busy = false;

  bool get isBusy => _busy;

  /// [json] を送り、応答を返す。[quiet] は送信内容のログを省く（同期・分割受信で何度も呼ぶため）。
  Future<BleReply> request(
    Map<String, dynamic> json, {
    required String label,
    bool quiet = false,
  }) async {
    if (!_link.isReady) {
      _log('❌ 未接続です。先に接続してください。');
      return const BleReply(BleReplyStatus.notReady);
    }
    if (_busy) {
      _log('⚠️ 送信中です。完了するまで次の送信はできません。');
      return const BleReply(BleReplyStatus.busy);
    }

    _busy = true;
    _link.beginTransfer();
    try {
      final jsonStr = jsonEncode(json);
      final bytes = utf8.encode('$jsonStr\n');
      final expectsResponse = _adapter.hasReadableResponse;
      late final int payloadSize;
      try {
        payloadSize = await _adapter.currentPayloadSize();
      } on BleAdapterException {
        _log('❌ BLEの送信可能サイズを取得できません。');
        await _link.abandonLink();
        return const BleReply(BleReplyStatus.linkFailed);
      }
      if (bytes.length > maxPayloadBytes) {
        _log('❌ $labelデータが大きすぎます (${bytes.length} bytes)。');
        _link.endTransfer();
        return const BleReply(BleReplyStatus.tooLarge);
      }
      if (!expectsResponse && bytes.length > payloadSize) {
        _log('BLEサーバーが応答特性を持たず、分割データも再構成できないため送信を中止しました。MTUを確認してください。');
        _link.endTransfer();
        return const BleReply(BleReplyStatus.tooLarge);
      }
      if (!quiet) {
        _log('📤 $label送信中 (${bytes.length} bytes)...');
        _log('   $jsonStr');
      }

      try {
        await _adapter.writeChunks(BlePayloadChunker.split(bytes, payloadSize));
      } on BleAdapterException catch (e) {
        _log('❌ 送信エラー: ${e.detail}');
        await _link.abandonLink();
        return const BleReply(BleReplyStatus.linkFailed);
      }
      if (!expectsResponse) {
        _log('BLE書き込み完了。サーバーからACKが返らないため、ROSでの受信・計画結果はPC側で確認してください。');
        _link.endTransfer();
        return const BleReply(BleReplyStatus.writtenWithoutResponse);
      }
      try {
        final response = await _adapter.readResponse(timeout: responseTimeout);
        // 応答が届いた以上、回線は生きている。中身の拒否（NACK など）は
        // 呼び出し側の失敗であり、接続は保つ。
        _link.endTransfer();
        return BleReply(BleReplyStatus.received, response);
      } on BleAdapterException catch (e) {
        _log('❌ 送信エラー: ${e.detail}');
        await _link.abandonLink();
        return const BleReply(BleReplyStatus.linkFailed);
      }
    } catch (e) {
      _log('❌ 送信エラー: $e');
      await _link.abandonLink();
      return const BleReply(BleReplyStatus.linkFailed);
    } finally {
      _busy = false;
    }
  }
}
