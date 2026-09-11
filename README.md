# MIRS BLE App

MIRS ロボットへ BLE 経由で清掃範囲ミッションを送信する Flutter アプリです。

## 構成

- `lib/models/cleaning_zone.dart`: 座標と清掃範囲ミッションのモデル、JSON 化、入力検証
- `lib/ble_service.dart`: BLE スキャン・接続・Characteristic 検出・送信・切断
- `lib/main.dart`: 権限要求と画面表示。通信や JSON の詳細はサービス・モデルに依存

## 実行と検証

```sh
flutter pub get
flutter analyze
flutter test
```

接続対象は、指定されたサービスUUID
（`12345678-1234-1234-1234-123456789abc`）を広告するデバイスだけです。
デバイス名は接続対象の判定には使用しません。

ミッション送信後はResponse Characteristic
（`12345678-1234-1234-1234-123456789abe`）を読み取り、`ACK` で受信側の検証・ROS 2配信成功、
`NACK` で失敗を判定します。

### Android release署名

releaseビルドはdebug署名へフォールバックしません。正式配布前に
`android/key.properties.example` を `android/key.properties` としてコピーし、
実際のkeystore情報を設定してください。`key.properties` とkeystoreファイルは
リポジトリへ追加しないでください。
