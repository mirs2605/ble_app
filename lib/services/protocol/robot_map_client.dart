import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../models/robot_map.dart';
import '../ble_request_channel.dart';
import 'json_reply.dart';

/// ロボットの地図を受け取る窓口。
abstract class RobotMapSource {
  /// ロボットが渡せる地図の説明を取得する。失敗は null。
  Future<RobotMapInfo?> pullMapInfo();

  /// [info] の地図データを分割して受け取る。失敗・不一致は null。
  /// [onProgress] には受信済みの bytes と全体の bytes を渡す。
  Future<Uint8List?> pullMapData(
    RobotMapInfo info, {
    void Function(int received, int total)? onProgress,
  });
}

/// 地図の受信手順（`map_info` / `map_chunk`、CRC32 の検証）だけを担う。
/// 契約は docs/map-transfer-contract.md。
class RobotMapClient implements RobotMapSource {
  RobotMapClient({
    required this._channel,
    required void Function(String message) onLog,
  }) : _log = onLog;

  /// 地図データを1回に受け取る生データの大きさ [bytes]。base64にすると約344文字で、
  /// JSONの枠を足しても1回の読み取り上限（約512 bytes）に収まる。
  static const mapChunkBytes = 256;

  final BleRequestChannel _channel;
  final void Function(String message) _log;

  @override
  Future<RobotMapInfo?> pullMapInfo() async {
    final reply = await _channel.request({'type': 'map_info'}, label: '地図の情報');
    final json = reply.received ? decodeJsonObject(reply.bytes) : null;
    if (json == null) {
      if (reply.received) {
        _log('❌ ロボット側で地図の情報が拒否されました: ${describeResponse(reply.bytes)}');
      }
      _log('❌ ロボットの地図情報を取得できませんでした。');
      return null;
    }
    try {
      return RobotMapInfo.fromJson(json);
    } on FormatException catch (e) {
      _log('❌ 地図情報が不正です: ${e.message}');
      return null;
    }
  }

  @override
  Future<Uint8List?> pullMapData(
    RobotMapInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final data = BytesBuilder(copy: false);
    var received = 0;
    onProgress?.call(0, info.size);
    while (received < info.size) {
      final length = min(mapChunkBytes, info.size - received);
      final offset = received;
      final reply = await _channel.request(
        {'type': 'map_chunk', 'offset': offset, 'length': length},
        label: '地図データ',
        quiet: true,
      );
      final piece = reply.received
          ? decodeMapChunk(reply.bytes, offset: offset, maxLength: length)
          : null;
      if (piece == null) {
        _log('❌ 地図データの受信に失敗しました ($received/${info.size} bytes)。');
        return null;
      }
      data.add(piece);
      received += piece.length;
      onProgress?.call(received, info.size);
    }
    final bytes = data.takeBytes();
    final expected = info.crc32;
    if (expected != null && crc32(bytes) != expected) {
      _log('❌ 地図データが壊れています（CRC32が一致しません）。');
      return null;
    }
    return bytes;
  }

  /// `{"offset":N,"data":"<base64>"}` を読む。offset 違い・空・要求より長い応答は null。
  static Uint8List? decodeMapChunk(
    List<int> bytes, {
    required int offset,
    required int maxLength,
  }) {
    final json = decodeJsonObject(bytes);
    if (json == null || json['offset'] != offset) return null;
    final encoded = json['data'];
    if (encoded is! String) return null;
    try {
      final chunk = base64Decode(encoded);
      // 空・要求より長い応答は受け付けない（受信が進まず止まらなくなるため）。
      return chunk.isEmpty || chunk.length > maxLength ? null : chunk;
    } on FormatException {
      return null;
    }
  }
}
