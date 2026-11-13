// BLE通信のオーケストレーション。送受信の実体は [BleAdapter] に委ね、
// このクラスは状態遷移・ログ・再試行方針に徹する。
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../models/cleaning_zone.dart';
import '../models/robot_map.dart';
import '../models/schedule_entry.dart';
import 'ble_adapter.dart';
import 'ble_connection.dart';
import 'flutter_blue_plus_adapter.dart';

/// BLE接続の状態は [BleConnection] 側に定義（循環import回避）。
/// 既存の `ble_service.dart` からの参照互換のため再exportする。
export 'ble_connection.dart' show BleStatus;
export 'ble_protocol.dart'
    show BleUuids, BleTargetMatcher, BleConnectionRequirements;

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

class BleReconnectPolicy {
  const BleReconnectPolicy._();

  static bool shouldReconnect({
    required BleStatus status,
    required bool disposed,
  }) {
    return !disposed &&
        status != BleStatus.connected &&
        status != BleStatus.connecting &&
        status != BleStatus.sending;
  }
}

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

/// BLE通信を管理するサービス
class BleService implements BleConnection {
  static const scanTimeout = Duration(seconds: 8);
  static const connectTimeout = Duration(seconds: 10);
  static const responseTimeout = Duration(seconds: 5);
  static const maxPayloadBytes = 4096;

  /// 地図データを1回に受け取る生データの大きさ [bytes]。base64にすると約344文字で、
  /// JSONの枠を足しても1回の読み取り上限（約512 bytes）に収まる。
  static const mapChunkBytes = 256;

  final BleAdapter _adapter;
  StreamSubscription<void>? _linkLossSub;
  Timer? _autoScanTimer;
  bool _isDisposed = false;
  bool _isSending = false;
  bool _isReady = false;

  /// 現在の接続状態
  @override
  BleStatus status = BleStatus.idle;

  /// ログ出力コールバック
  final void Function(String message) onLog;

  /// 状態変化コールバック
  final void Function(BleStatus status) onStatusChanged;

  BleService({
    required this.onLog,
    required this.onStatusChanged,
    BleAdapter? adapter,
  }) : _adapter = adapter ?? FlutterBluePlusAdapter();

  @override
  void startAutoConnect() {
    if (_isDisposed || _autoScanTimer != null) {
      return;
    }

    _autoScanTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isDisposed ||
          status == BleStatus.connected ||
          status == BleStatus.connecting ||
          status == BleStatus.sending) {
        return;
      }
      await scanAndConnect();
    });
  }

  @override
  void stopAutoConnect() {
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  void _setStatus(BleStatus s) {
    if (_isDisposed) return;
    status = s;
    onStatusChanged(s);
  }

  void _log(String msg) {
    if (_isDisposed) return;
    onLog(msg);
  }

  @override
  Future<void> scanAndConnect() async {
    if (_isDisposed ||
        status == BleStatus.scanning ||
        status == BleStatus.connecting) {
      return;
    }

    try {
      await _adapter.ensurePoweredOn();
    } on BleAdapterException catch (e) {
      if (e.failure == BleAdapterFailure.bluetoothOff) {
        _log('❌ スマホのBluetoothがOFFです。ONにしてください。');
      } else {
        _log('❌ スキャンエラー: ${e.detail}');
      }
      _setStatus(BleStatus.error);
      return;
    }

    _setStatus(BleStatus.scanning);
    _log('🔍 ターゲット BLE をスキャン中...');

    late final BleFoundDevice? found;
    try {
      found = await _adapter.findTarget(
        timeout: scanTimeout,
        onAdvertisement: (name, remoteId) {
          if (name.isNotEmpty) {
            _log('  発見: "$name" ($remoteId)');
          }
        },
      );
    } on BleAdapterException catch (e) {
      _log('❌ スキャンエラー: ${e.detail}');
      _setStatus(BleStatus.error);
      return;
    }
    if (found == null) {
      _log('❌ MIRS-Robot が見つかりませんでした (タイムアウト)');
      _setStatus(BleStatus.idle);
      return;
    }
    _log('🎯 ターゲット検出: ${found.name} (${found.remoteId})');
    await _connect(found);
  }

  Future<void> _connect(BleFoundDevice found) async {
    if (_isDisposed || status == BleStatus.connected) {
      return;
    }

    _setStatus(BleStatus.connecting);
    _log('🔗 接続中: ${found.name}');

    try {
      await _adapter.connect(found.remoteId, timeout: connectTimeout);
    } on BleAdapterException catch (e) {
      if (e.failure == BleAdapterFailure.requirementsUnmet) {
        _log('❌ Mission Characteristic が見つかりません。');
      } else {
        _log('❌ 接続エラー: ${e.detail}');
      }
      _setStatus(BleStatus.error);
      return;
    }
    _log('✅ 接続成功');

    final mtu = await _adapter.negotiateMtu();
    if (mtu.requested) {
      _log('ℹ️ MTUを設定しました: ${mtu.mtu} bytes');
    } else if (mtu.requestFailed) {
      _log('⚠️ MTU設定に失敗したため、現在値を使用します: ${mtu.mtu} bytes');
    } else {
      _log('ℹ️ 現在のMTU: ${mtu.mtu} bytes');
    }

    _isReady = true;
    _setStatus(BleStatus.connected);
    _watchLinkLoss();
  }

  void _watchLinkLoss() {
    _linkLossSub?.cancel();
    _linkLossSub = _adapter.linkLoss.listen((_) => _handleLinkLoss());
  }

  void _handleLinkLoss() {
    if (_isDisposed) return;
    _isReady = false;
    _log('🔌 切断されました');
    _setStatus(BleStatus.disconnected);
    if (BleReconnectPolicy.shouldReconnect(
      status: status,
      disposed: _isDisposed,
    )) {
      Future.microtask(() => scanAndConnect());
    }
  }

  @override
  Future<bool> sendCleaningZone(CleaningZoneMission zone) async {
    if (!zone.isValid) {
      _log('❌ 清掃範囲が不正です。');
      return false;
    }
    return _sendJson(zone.toJson(), label: '清掃範囲');
  }

  @override
  Future<bool> pushSchedule(ScheduleEntry entry) async {
    if (!entry.isValid) {
      _log('❌ 定時清掃の設定が不正です。');
      return false;
    }
    return _sendJson({
      'type': 'schedule_upsert',
      ...entry.toJson(),
    }, label: '定時清掃');
  }

  /// 予定を1件ずつ取得する。要求（`schedule_pull`）を書き込み、
  /// Response Characteristic に置かれた1件分のJSONを読む。
  @override
  Future<List<ScheduleEntry>?> pullSchedules() async {
    final entries = <ScheduleEntry>[];
    var count = 1;
    for (var index = 0; index < count; index++) {
      Map<String, dynamic>? reply;
      final ok = await _sendJson(
        {'type': 'schedule_pull', 'index': index},
        label: '予定の取得',
        quiet: true,
        acceptResponse: (bytes) {
          reply = _decodeJsonObject(bytes);
          return reply != null;
        },
      );
      final page = reply;
      if (!ok || page == null) {
        _log('❌ 予定を取得できませんでした。');
        return null;
      }
      final total = page['count'];
      if (total is! int || total < 0) {
        _log('❌ 予定の件数が不正です。');
        return null;
      }
      count = total.clamp(0, ScheduleEntry.maxEntries);
      final item = page['item'];
      if (count == 0 || item is! Map) continue;
      try {
        entries.add(ScheduleEntry.fromJson(Map<String, dynamic>.from(item)));
      } on FormatException catch (e) {
        _log('⚠️ 不正な予定を読み飛ばしました: ${e.message}');
      }
    }
    return entries;
  }

  /// 地図の説明を取得する（`map_info`）。応答は Response のJSON。
  @override
  Future<RobotMapInfo?> pullMapInfo() async {
    Map<String, dynamic>? reply;
    final ok = await _sendJson(
      {'type': 'map_info'},
      label: '地図の情報',
      acceptResponse: (bytes) {
        reply = _decodeJsonObject(bytes);
        return reply != null;
      },
    );
    final json = reply;
    if (!ok || json == null) {
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

  /// 地図データを [mapChunkBytes] ずつ取得する（`map_chunk`）。
  /// 応答は `{"offset":N,"data":"<base64>"}`。1回の読み取りが約512 bytesまでのため、
  /// 生データは小さく区切る。CRC32が付いていれば全体を検証する。
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
      Uint8List? chunk;
      final ok = await _sendJson(
        {'type': 'map_chunk', 'offset': offset, 'length': length},
        label: '地図データ',
        quiet: true,
        acceptResponse: (bytes) {
          chunk = _decodeMapChunk(bytes, offset: offset, maxLength: length);
          return chunk != null;
        },
      );
      final piece = chunk;
      if (!ok || piece == null) {
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

  static Uint8List? _decodeMapChunk(
    List<int> bytes, {
    required int offset,
    required int maxLength,
  }) {
    final json = _decodeJsonObject(bytes);
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

  static Map<String, dynamic>? _decodeJsonObject(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  /// JSON化可能なオブジェクトを改行区切りでBLE送信する共通実装。
  ///
  /// 接続チェック・チャンク分割・ACK確認を担い、上位メソッドはバリデーションのみ。
  ///
  /// [acceptResponse] を渡すと、応答が `ACK` かどうかの代わりにそれで成否を決める
  /// （予定の取得のように、応答にデータが載る場合）。[quiet] は送信内容と
  /// 完了のログを省く（同期で何度も呼ぶため）。
  Future<bool> _sendJson(
    Map<String, dynamic> json, {
    required String label,
    bool Function(List<int> response)? acceptResponse,
    bool quiet = false,
  }) async {
    if (!_isReady) {
      _log('❌ 未接続です。先に接続してください。');
      return false;
    }
    if (_isSending) {
      _log('⚠️ 送信中です。完了するまで次の送信はできません。');
      return false;
    }

    _isSending = true;
    _setStatus(BleStatus.sending);
    try {
      final jsonStr = jsonEncode(json);
      final bytes = utf8.encode('$jsonStr\n');
      final expectsAck = _adapter.hasReadableResponse;
      late final int payloadSize;
      try {
        payloadSize = await _adapter.currentPayloadSize();
      } on BleAdapterException {
        _log('❌ BLEの送信可能サイズを取得できません。');
        _setStatus(BleStatus.error);
        return false;
      }
      if (bytes.length > maxPayloadBytes) {
        _log('❌ $labelデータが大きすぎます (${bytes.length} bytes)。');
        _setStatus(BleStatus.connected);
        return false;
      }
      if (!expectsAck && bytes.length > payloadSize) {
        _log('BLEサーバーが応答特性を持たず、分割データも再構成できないため送信を中止しました。MTUを確認してください。');
        _setStatus(BleStatus.connected);
        return false;
      }
      if (!quiet) {
        _log('📤 $label送信中 (${bytes.length} bytes)...');
        _log('   $jsonStr');
      }

      try {
        await _adapter.writeChunks(BlePayloadChunker.split(bytes, payloadSize));
      } on BleAdapterException catch (e) {
        _log('❌ 送信エラー: ${e.detail}');
        _isReady = false;
        _setStatus(BleStatus.error);
        return false;
      }
      if (!expectsAck) {
        _log('BLE書き込み完了。サーバーからACKが返らないため、ROSでの受信・計画結果はPC側で確認してください。');
        _setStatus(BleStatus.connected);
        return acceptResponse == null;
      }
      late final List<int> response;
      try {
        response = await _adapter.readResponse(timeout: responseTimeout);
      } on BleAdapterException catch (e) {
        _log('❌ 送信エラー: ${e.detail}');
        _isReady = false;
        _setStatus(BleStatus.error);
        return false;
      }
      final accepted = acceptResponse != null
          ? acceptResponse(response)
          : BleResponse.isAccepted(response);
      if (!accepted) {
        final responseText = utf8.decode(response, allowMalformed: true);
        _log('❌ ロボット側で$labelが拒否されました: $responseText');
        _setStatus(BleStatus.error);
        return false;
      }
      if (!quiet) _log('✅ $label送信完了');
      _setStatus(BleStatus.connected);
      return true;
    } catch (e) {
      _log('❌ 送信エラー: $e');
      _setStatus(BleStatus.error);
      return false;
    } finally {
      _isSending = false;
    }
  }

  Future<void> disconnect() async {
    await _linkLossSub?.cancel();
    _linkLossSub = null;
    _isReady = false;
    _isSending = false;
    try {
      await _adapter.disconnect();
    } catch (_) {}
    if (!_isDisposed) {
      _setStatus(BleStatus.idle);
    }
    _log('🔌 切断しました');
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    stopAutoConnect();
    await disconnect();
    try {
      await _adapter.dispose();
    } catch (_) {}
  }
}
