/// BLEプロトコル定数と純粋判定ロジック。flutter_blue_plusへの依存なし。
/// Adapter実装とService・テストの共通基盤。
abstract final class BleUuids {
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String missionCharUuid = '12345678-1234-1234-1234-123456789abd';
  static const String responseCharUuid = '12345678-1234-1234-1234-123456789abe';
}

class BleTargetMatcher {
  const BleTargetMatcher._();

  static bool matchesServiceUuid(Iterable<String> advertisedUuids) {
    return advertisedUuids.any(
      (uuid) => uuid.toLowerCase() == BleUuids.serviceUuid.toLowerCase(),
    );
  }
}

class BleConnectionRequirements {
  const BleConnectionRequirements._();

  static bool hasWritableMissionAndReadableResponse({
    required bool missionFound,
    required bool missionWritable,
    required bool responseFound,
    required bool responseReadable,
  }) {
    return missionFound && missionWritable && responseFound && responseReadable;
  }
}
