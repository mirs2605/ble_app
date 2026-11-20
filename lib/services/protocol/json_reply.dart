import 'dart:convert';

/// 応答のバイト列を JSON オブジェクトとして読む。読めなければ null（`NACK` など）。
Map<String, dynamic>? decodeJsonObject(List<int> bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}

/// 拒否された応答をログ用の文字列にする。
String describeResponse(List<int> bytes) =>
    utf8.decode(bytes, allowMalformed: true);
