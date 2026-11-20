# Project Map — 索引

最終確認: 2026-11-20（`feature/decouple-connection` / fe5853d 時点のコードで確認）

開始地点（initial pose）・数値入力タブ・PC シミュレーション接続は廃止済み。

## 概要

- 目的: 地図上で清掃範囲（多角形。フリーハンド・ひな形）を指定し、BLE でロボットへ送信する。定時清掃の予定の同期と、ロボットの SLAM 地図の受信も BLE で行う。
- 技術: Flutter / Dart（SDK ^3.13）、flutter_blue_plus、sqflite、image_picker、permission_handler。
- エントリーポイント: `lib/main.dart`（`MapConfigRepository.init()` → `BleHomeController` 生成）。

## 作業別の入口

| 作業内容 | 最初に読むファイル | 関連テスト |
|---|---|---|
| 画面全体・状態の配線 | `lib/controllers/ble_home_controller.dart` | `test/ble_home_controller_test.dart` |
| 地図上の範囲描画・タップ操作 | `lib/widgets/map_selection_area.dart`, `lib/services/map_selection_controller.dart` | `test/map_selection_area_test.dart` |
| ひな形（星など）・頂点数 | `lib/models/shape_template.dart`, `lib/widgets/ble_tabs.dart`（`ShapeTemplateButton` / `VertexCountSlider`） | `test/shape_template_test.dart` |
| 座標変換・地図定数 | `lib/models/map_geometry.dart`, `lib/models/map_config.dart`（`BuiltinMaps`） | `test/widget_test.dart` |
| 送信 JSON・入力検証 | `lib/models/cleaning_zone.dart` | `test/widget_test.dart` |
| BLE 接続・送信・ACK | `lib/services/ble_service.dart` → `ble_adapter.dart` / `ble_protocol.dart` | `test/ble_service_test.dart` |
| 送信ボタンの状態遷移 | `lib/controllers/send_mission_tracker.dart`, `lib/widgets/mission_send_button.dart` | `test/send_mission_tracker_test.dart`, `test/mission_send_button_test.dart` |
| 通知バー・ステータス表示 | `lib/controllers/notice_board.dart`, `lib/widgets/status_notification_bar.dart`, `lib/models/app_notice.dart` | `test/notice_board_test.dart`, `test/status_notification_bar_test.dart` |
| 地図の追加・切替・削除（地図一覧タブ） | `lib/widgets/map_management_button.dart`, `lib/controllers/map_catalog.dart`, `lib/services/map_config_repository.dart`, `map_image_storage.dart` | `test/map_management_button_test.dart`, `test/map_catalog_test.dart`, `test/map_config_repository_test.dart` |
| ロボットからの地図受信 | `lib/controllers/robot_map_receiver.dart`, `lib/services/pgm_codec.dart`, `lib/models/robot_map.dart` | `test/robot_map_receive_test.dart` |
| 定時清掃の予定（予定タブ・同期） | `lib/controllers/schedule_coordinator.dart`, `lib/services/schedule_sync.dart`, `lib/widgets/schedule_dialog.dart` | `test/schedule_sync_test.dart`, `test/schedule_coordinator_test.dart`, `test/schedule_tab_test.dart` |
| タブ・ログ画面 | `lib/widgets/ble_tabs.dart`, `lib/widgets/icon_tab_navigation.dart` | `test/ble_home_controller_test.dart`, `test/log_buffer_test.dart` |
| 文言・色・ピル表示 | `lib/theme/app_strings.dart`, `app_colors.dart`, `pill_style.dart` | — |
| 権限 | `lib/services/permission_gateway.dart`, `permission_service.dart` | `test/ble_home_controller_test.dart` |
| CI | `.github/workflows/ci.yaml`（`flutter analyze` + `flutter test`） | — |

## 詳細

- [ARCHITECTURE.md](ARCHITECTURE.md): レイヤー構成と送信までの処理の流れ
- [MODULES.md](MODULES.md): ファイルごとの役割
- [DEPENDENCIES.md](DEPENDENCIES.md): 依存関係、変更時の影響範囲、注意点

## 既存の資料

- [../backlog.md](../backlog.md): 残件と優先度（アプリ層）
- [../reviews/configuration-review.md](../reviews/configuration-review.md): BLE 契約・署名・権限のレビュー記録

## マップの保守

- 古くなった部分だけを更新する（`/project-map` スキル）。
- 未確認の内容には「未確認」と明記する。
- ソースコードや全ファイルの一覧をここに書き写さない。
