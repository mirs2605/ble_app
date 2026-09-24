/// [BleAdapter] の失敗種別。Serviceはこれで状態遷移とログを決める。
enum BleAdapterFailure {
  bluetoothOff,
  scanFailed,
  connectFailed,
  requirementsUnmet,
  mtuUnavailable,
  writeFailed,
  responseTimeout,
  readFailed,
}

class BleAdapterException implements Exception {
  final BleAdapterFailure failure;
  final String? detail;

  const BleAdapterException(this.failure, [this.detail]);

  @override
  String toString() => 'BleAdapterException($failure${detail == null ? '' : ', $detail'})';
}

/// スキャンで見つかったターゲット。プリミティブ型のみで表現し、
/// Fake実装がflutter_blue_plusなしで済むようにする。
class BleFoundDevice {
  final String remoteId;
  final String name;

  const BleFoundDevice({required this.remoteId, required this.name});
}

/// MTUネゴシエーション結果。ログ出し分けに必要な情報も含める。
class BleMtuInfo {
  final int mtu;
  final int payloadSize;
  final bool requested;
  final bool requestFailed;

  const BleMtuInfo({
    required this.mtu,
    required this.payloadSize,
    required this.requested,
    required this.requestFailed,
  });
}

typedef BleAdvertisementCallback =
    void Function(String name, String remoteId);

/// BLE送受信の抽象。flutter_blue_plusのstatic APIとデバイス操作を
/// この裏に隠し、ServiceをFakeで単体テスト可能にする。
/// 実装はデバイス固有オブジェクトを内部に保持し、公開面は
/// プリミティブ型とDTOに限定する。
abstract class BleAdapter {
  /// OSのBluetoothがONであることを確認。OFFなら
  /// [BleAdapterFailure.bluetoothOff] を投げる。
  Future<void> ensurePoweredOn();

  /// ターゲットをスキャンする。タイムアウト時はnullを返す。
  /// 見つけた広告は [onAdvertisement] で逐次通知する。
  /// スキャン自体の失敗は [BleAdapterFailure.scanFailed] を投げる。
  Future<BleFoundDevice?> findTarget({
    required Duration timeout,
    BleAdvertisementCallback? onAdvertisement,
  });

  /// 接続＋サービス探索。要件（mission書き込み可・response読み取り可）を
  /// 満たさなければ [BleAdapterFailure.requirementsUnmet] を投げる。
  Future<void> connect(String remoteId, {required Duration timeout});

  /// MTUネゴシエーション。未接続で呼ぶと
  /// [BleAdapterFailure.connectFailed] を投げる。
  Future<BleMtuInfo> negotiateMtu();

  /// 現在の1回あたり送信可能サイズ。取得不能なら
  /// [BleAdapterFailure.mtuUnavailable] を投げる。
  Future<int> currentPayloadSize();

  /// チャンク列を順に書き込む。失敗は
  /// [BleAdapterFailure.writeFailed] を投げる。
  Future<void> writeChunks(List<List<int>> chunks);

  /// 応答を読み取る。タイムアウトは
  /// [BleAdapterFailure.responseTimeout]、その他は
  /// [BleAdapterFailure.readFailed] を投げる。
  Future<List<int>> readResponse({required Duration timeout});

  /// リンク断の通知。Serviceは購読して再スキャン方針を適用する。
  Stream<void> get linkLoss;

  Future<void> disconnect();

  Future<void> dispose();
}
