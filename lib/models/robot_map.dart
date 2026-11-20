/// ロボットが BLE で渡す地図の説明（`map_info` への応答）。
///
/// 地図本体は別途 `map_chunk` で分割して受け取る。[format] は `png` か `pgm`
/// （SLAM の map_saver が出す形式）。[resolution]・[originX]・[originY] は
/// map.yaml と同じ単位 [m]。
class RobotMapInfo {
  const RobotMapInfo({
    required this.name,
    required this.format,
    required this.size,
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    this.crc32,
  });

  /// 受け取れる地図データの上限 [bytes]。
  static const int maxBytes = 4 * 1024 * 1024;

  /// 受け取れる画像の一辺の上限 [px]。
  static const int maxSide = 4096;

  static const formats = {'png', 'pgm'};

  final String name;
  final String format;

  /// 地図データ全体の大きさ [bytes]。
  final int size;
  final int width;
  final int height;
  final double resolution;
  final double originX;
  final double originY;

  /// 地図データ全体の CRC32。ロボットが付けたときだけ検証する。
  final int? crc32;

  bool get isPgm => format == 'pgm';

  /// 応答の JSON から作る。不正なら [FormatException]。
  factory RobotMapInfo.fromJson(Map<String, dynamic> json) {
    int integer(String key) {
      final value = json[key];
      if (value is int) return value;
      throw FormatException('$key が整数ではありません');
    }

    double number(String key) {
      final value = json[key];
      if (value is num && value.isFinite) return value.toDouble();
      throw FormatException('$key が数値ではありません');
    }

    final format = json['format'];
    if (format is! String || !formats.contains(format)) {
      throw const FormatException('format は png か pgm にしてください');
    }
    final rawName = json['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'ロボットの地図';
    final size = integer('size');
    final width = integer('width');
    final height = integer('height');
    final resolution = number('resolution');
    if (size <= 0 || size > maxBytes) {
      throw FormatException('地図の大きさが範囲外です ($size bytes)');
    }
    if (width <= 0 || width > maxSide || height <= 0 || height > maxSide) {
      throw FormatException('画像の寸法が範囲外です ($width × $height)');
    }
    if (resolution <= 0) {
      throw const FormatException('resolution は 0 より大きくしてください');
    }
    final crc = json['crc32'];
    if (crc != null && (crc is! int || crc < 0 || crc > 0xFFFFFFFF)) {
      throw const FormatException('crc32 が不正です');
    }
    return RobotMapInfo(
      name: name,
      format: format,
      size: size,
      width: width,
      height: height,
      resolution: resolution,
      originX: number('origin_x'),
      originY: number('origin_y'),
      crc32: crc as int?,
    );
  }
}

/// CRC32（IEEE 802.3、zlib・PNG と同じ多項式）。
int crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
