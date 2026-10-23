# Dependencies and cautions

## lib 内の依存方向

```
widgets ─✕→ controllers（widgets は Controller を import しない。main.dart が値とコールバックを渡す）
widgets ─→ services(map_selection_controller, initial_pose_controller, map_image_storage, ble_service の BleStatus) / models / theme
controllers/ble_home_controller ─→ services(ほぼ全部) / models / theme/app_strings
services ─→ models（ble_service・ble_adapter・ble_protocol は models 以外に lib 内依存なし）
theme/app_strings, pill_style ─→ services/ble_service（BleStatus 用） / models
models ─→ models のみ
```

- `BleStatus` の定義は `ble_connection.dart` にある。`ble_service.dart` が再 export しているため、widgets や theme は `ble_service.dart` から import している（循環 import を避けるため）。
- import は相対パスで書かれている（`main.dart` もパッケージ内は相対 import）。

## 変更時の影響範囲

| 変更するもの | 影響を受けるもの・確認すること |
|---|---|
| `BleConnection` のインターフェース | `BleService`、`PcSimulationConnection`、`FakeBleConnection`（`test/ble_home_controller_test.dart`） |
| `BleAdapter` | `FlutterBluePlusAdapter`、`ble_service_test.dart` の Fake |
| 送信 JSON（`toJson` / `type` / 閉路形式） | ロボット側の `ble_server`（別リポジトリ）、`http_gateway.py`。**サーバー側を先に更新してから反映する**（backlog #13） |
| UUID（`BleUuids`） | `ble_server` の GATT 設定、README の記載 |
| 地図定数（`BuiltinMaps` / `MapGeometry`） | `test/widget_test.dart` の期待値を再計算する（AGENTS.md） |
| `MapConfig` のフィールド | `map_config_repository.dart` の DB スキーマ（`_dbVersion = 1`。`onUpgrade` はまだないため、スキーマを変えるときは追加が必要）、`map_management_button.dart` |
| `SendButtonState` / `AppNotice` | `pill_style.dart`、`app_strings.dart`、`mission_send_button.dart`、`status_notification_bar.dart` |
| `BleHomeController` の公開 API | `main.dart`、`ble_tabs.dart`、`ble_home_controller_test.dart` |

## 外部依存

- 実行時: flutter_blue_plus（BLE）、permission_handler、sqflite、path_provider、image_picker、vector_math。
- テスト: flutter_test、sqflite_common_ffi。
- ROS 側: ROS 2 Jazzy、OpenNav Coverage（`ros2_ws/opennav_coverage.repos`）、Fields2Cover。
- 未確認: backlog が参照している `ws/TODO.md` はこのリポジトリの外にある。

## 注意点

- 浮動小数点の比較は `moreOrLessEquals` / `closeTo` を使う。
- `MapConfigRepository` はシングルトン。テストでは DB を差し替えるか、`mapRepository` を注入する。
- `ble_service.dart` の診断ログは開発者向け（多言語化の対象外）。
- release ビルドには `android/key.properties` が必要（リポジトリに含めない）。
