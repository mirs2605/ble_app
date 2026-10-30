import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// PGM（P5 バイナリ・P2 テキスト）の画像を PNG に変換する。
///
/// SLAM の map_saver が出す地図は PGM で、Flutter の画像表示は PGM を読めない。
/// 画素値はそのまま濃淡にする（通行可=白、障害物=黒、未知=灰）。
/// 不正なデータは [FormatException]。
Future<Uint8List> pgmToPng(Uint8List data) async {
  final pgm = _parse(data);
  final rgba = Uint8List(pgm.width * pgm.height * 4);
  for (var i = 0; i < pgm.pixels.length; i++) {
    final gray = pgm.maxValue == 255
        ? pgm.pixels[i]
        : (pgm.pixels[i] * 255 ~/ pgm.maxValue);
    rgba[i * 4] = gray;
    rgba[i * 4 + 1] = gray;
    rgba[i * 4 + 2] = gray;
    rgba[i * 4 + 3] = 255;
  }
  final image = await _decode(rgba, pgm.width, pgm.height);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const FormatException('PNG に変換できませんでした');
    return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } finally {
    image.dispose();
  }
}

/// PNG の幅と高さ（IHDR）を返す。PNG として読めなければ null。
(int, int)? pngDimensions(Uint8List png) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (png.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (png[i] != signature[i]) return null;
  }
  final header = ByteData.sublistView(png, 8, 24);
  if (header.getUint32(4) != 0x49484452) return null; // 'IHDR'
  final width = header.getUint32(8);
  final height = header.getUint32(12);
  if (width == 0 || height == 0) return null;
  return (width, height);
}

Future<ui.Image> _decode(Uint8List rgba, int width, int height) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

class _Pgm {
  const _Pgm(this.width, this.height, this.maxValue, this.pixels);

  final int width;
  final int height;
  final int maxValue;
  final Uint8List pixels;
}

_Pgm _parse(Uint8List data) {
  var pos = 0;

  // 空白とコメント（# から行末）を読み飛ばす。
  void skipSpace() {
    while (pos < data.length) {
      final c = data[pos];
      if (c == 0x23) {
        while (pos < data.length && data[pos] != 0x0A) {
          pos++;
        }
      } else if (c == 0x20 || (c >= 0x09 && c <= 0x0D)) {
        pos++;
      } else {
        break;
      }
    }
  }

  String token() {
    skipSpace();
    final start = pos;
    while (pos < data.length) {
      final c = data[pos];
      if (c == 0x20 || (c >= 0x09 && c <= 0x0D) || c == 0x23) break;
      pos++;
    }
    return String.fromCharCodes(data.sublist(start, pos));
  }

  int integer(String what) {
    final value = int.tryParse(token());
    if (value == null) throw FormatException('PGM の$whatが読めません');
    return value;
  }

  final magic = token();
  if (magic != 'P5' && magic != 'P2') {
    throw const FormatException('PGM（P5 または P2）ではありません');
  }
  final width = integer('幅');
  final height = integer('高さ');
  final maxValue = integer('最大値');
  if (width <= 0 || height <= 0 || width > 4096 || height > 4096) {
    throw FormatException('PGM の寸法が範囲外です ($width × $height)');
  }
  if (maxValue <= 0 || maxValue > 255) {
    throw FormatException('PGM の最大値が未対応です ($maxValue)');
  }

  final count = width * height;
  final pixels = Uint8List(count);
  if (magic == 'P5') {
    pos++; // 最大値の直後の空白1文字
    if (data.length - pos < count) {
      throw const FormatException('PGM の画素が足りません');
    }
    pixels.setRange(0, count, data, pos);
  } else {
    for (var i = 0; i < count; i++) {
      pixels[i] = integer('画素');
    }
  }
  for (final value in pixels) {
    if (value > maxValue) throw const FormatException('PGM の画素値が範囲外です');
  }
  return _Pgm(width, height, maxValue, pixels);
}
