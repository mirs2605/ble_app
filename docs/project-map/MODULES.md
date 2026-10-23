# Modules

行数は目安（2026-10-23 時点）。★ は大きめのファイルで、該当箇所を検索してから部分的に読むこと。

## lib/

| ファイル | 役割 |
|---|---|
| `main.dart` | 起動、`MirsBleApp`（ダーク テーマ）、`BleHomePage`（Controller を生成し、タブを組み立てる） |

### controllers/

| ファイル | 役割 |
|---|---|
| `ble_home_controller.dart` ★423 | 画面の facade。接続状態・権限・地図・選択・開始地点・送信・ログ・通知を公開する |
| `send_mission_tracker.dart` | 送信の進行状況 → `SendButtonState` |
| `notice_board.dart` | 一定時間だけ値を表示する汎用ボード（`TimerScheduler` を注入可能） |

### models/

| ファイル | 役割 |
|---|---|
| `cleaning_zone.dart` | `MapPoint`、`CleaningZoneMission`（JSON 化。閉路に変換。座標の範囲と frame_id を検証） |
| `initial_pose.dart` | `InitialPoseMission`（x, y, theta の JSON と検証） |
| `map_config.dart` | `MapConfig`（画像・解像度・原点）、`BuiltinMaps`（学生玄関・MIRS の組み込み地図） |
| `map_geometry.dart` | 画面 ⇄ 地図座標の変換、6頂点の定数、旧来の互換用の既定値 |
| `map_edit_mode.dart` / `send_button_state.dart` / `app_notice.dart` | 状態を表す enum |

### services/

| ファイル | 役割 |
|---|---|
| `ble_connection.dart` | `BleStatus`、抽象 `BleConnection`、`BleConnectionFactory` |
| `ble_service.dart` ★351 | BLE 実装: 自動スキャン・接続・Characteristic の検出・MTU 調整・分割送信・ACK の判定・再接続。`BleStatus` を再 export |
| `ble_adapter.dart` | flutter_blue_plus を隠すための抽象 `BleAdapter` と例外・値型 |
| `flutter_blue_plus_adapter.dart` | `BleAdapter` の本番実装 |
| `ble_protocol.dart` | UUID 定数、ターゲットの判定、接続要件の判定（いずれも純粋関数） |
| `pc_simulation_connection.dart` | `BleConnection` の HTTP 実装（127.0.0.1:8765） |
| `map_selection_controller.dart` | 範囲の頂点編集、ハンドルの判定 |
| `initial_pose_controller.dart` | 開始地点の位置・向きの入力 |
| `map_config_repository.dart` | sqflite で地図一覧と選択中の地図を永続化（シングルトン。`init()` が必要） |
| `map_image_storage.dart` | 端末で選んだ地図画像をアプリ領域へコピー |
| `permission_gateway.dart` / `permission_service.dart` | Bluetooth（scan / connect）の権限要求（Gateway は注入用の抽象） |

### widgets/

| ファイル | 役割 |
|---|---|
| `ble_tabs.dart` ★499 | `BleHomeTab`（地図）、`BleValuesTab`（数値入力・開始地点フォーム）、`BleLogsTab` |
| `map_selection_area.dart` ★589 | 地図の描画、ジェスチャー、拡大鏡、範囲・開始地点の Painter |
| `map_management_button.dart` ★347 | 地図の切替・追加・削除ダイアログ |
| `map_selection_actions.dart` / `bottom_send_action.dart` / `mission_send_button.dart` | 送信・クリア操作の UI |
| `status_notification_bar.dart` / `ble_status_indicator.dart` | 通知バー・接続状態のピル（`SelectedTabIcon` もここ） |
| `icon_tab_navigation.dart` / `polygon_form.dart` / `permission_settings_button.dart` / `frosted_glass.dart` | 小さな UI 部品 |
| `floating_action_controls.dart` | ボタンをまとめて export するだけのファイル |

### theme/

`app_strings.dart`（UI 文言。`AppNotice` の表示拡張）、`app_colors.dart`、`pill_style.dart`（状態 → ピルの見た目）。

## test/

テスト対象と同じ名前のファイルに `_test.dart` を付けた構成。`widget_test.dart` は座標変換・モデル・アプリ起動の総合テスト（地図定数の期待値を含む）。DB を使うテストは `sqflite_common_ffi` を使う。

## ros2_ws/src/mirs_pc_viewer/

| ファイル | 役割 |
|---|---|
| `mirs_pc_viewer/http_gateway.py` | HTTP POST（`/cleaning_zone`, `/initial_pose`）→ ROS topic |
| `mirs_pc_viewer/coverage_preview.py` | `/cleaning_zone` → OpenNav Coverage action → `/coverage/path`・`/coverage/state` |
| `launch/preview.launch.py` / `config/coverage_server.yaml` / `rviz/` | 起動構成・経路の幅・RViz の設定 |
