# Modules

行数は目安（2026-10-23・main 時点）。★ は大きめのファイルで、該当箇所を検索してから部分的に読むこと。

## lib/

| ファイル | 役割 |
|---|---|
| `main.dart` | 起動、`MirsBleApp`（ダーク テーマ）、`BleHomePage`（Controller を生成し、タブを組み立てる） |

### controllers/

| ファイル | 役割 |
|---|---|
| `ble_home_controller.dart` ★414 | 画面の facade。接続状態・権限・地図・選択・開始地点・送信・ログ・通知を公開する |
| `send_mission_tracker.dart` | 送信の進行状況 → `SendButtonState` |
| `notice_board.dart` | 一定時間だけ値を表示する汎用ボード（`TimerScheduler` を注入可能） |

### models/

| ファイル | 役割 |
|---|---|
| `cleaning_schedule.dart` | `CleaningScheduleMission`（時刻・曜日・範囲の定時清掃。検証と JSON 化）、`CleaningScheduleCancel`。契約は [../schedule-contract.md](../schedule-contract.md) |
| `cleaning_zone.dart` | `MapPoint`、`CleaningZoneMission`（JSON 化。閉路に変換。座標の範囲・頂点数（3点以上）・frame_id を検証） |
| `initial_pose.dart` | `InitialPoseMission`（x, y, theta の JSON と検証） |
| `map_config.dart` | `MapConfig`（画像・解像度・原点）、`BuiltinMaps`（学生玄関・MIRS の組み込み地図） |
| `map_geometry.dart` | 画面 ⇄ 地図座標の変換、四角形の生成（`rectangleFrom` / `rectangleFromPath`）、旧来の互換用の既定値 |
| `map_edit_mode.dart` / `send_button_state.dart` / `app_notice.dart` | 状態を表す enum |

### services/

| ファイル | 役割 |
|---|---|
| `ble_connection.dart` | `BleStatus`、抽象 `BleConnection`、`BleConnectionFactory` |
| `ble_service.dart` ★337 | BLE 実装: 自動スキャン・接続・Characteristic の検出・MTU 調整・分割送信・ACK の判定・再接続。`BleStatus` を再 export |
| `ble_adapter.dart` | flutter_blue_plus を隠すための抽象 `BleAdapter` と例外・値型 |
| `flutter_blue_plus_adapter.dart` | `BleAdapter` の本番実装 |
| `ble_protocol.dart` | UUID 定数、ターゲットの判定、接続要件の判定（いずれも純粋関数） |
| `map_selection_controller.dart` | 四角形の範囲の生成と頂点編集、ハンドルの判定 |
| `initial_pose_controller.dart` | 開始地点の位置・向きの入力 |
| `map_config_repository.dart` | sqflite で地図一覧と選択中の地図を永続化（シングルトン。`init()` が必要） |
| `map_image_storage.dart` | 端末で選んだ地図画像をアプリ領域へコピー |
| `permission_gateway.dart` / `permission_service.dart` | Bluetooth（scan / connect）の権限要求（Gateway は注入用の抽象） |

### widgets/

| ファイル | 役割 |
|---|---|
| `ble_tabs.dart` ★501 | `BleHomeTab`（地図）、`BleValuesTab`（4点の数値入力・開始地点フォーム）、`BleLogsTab` |
| `map_selection_area.dart` ★585 | 地図の描画、ジェスチャー、拡大鏡、範囲・開始地点の Painter |
| `map_management_button.dart` ★347 | 地図の切替・追加・削除ダイアログ |
| `map_selection_actions.dart` / `bottom_send_action.dart` / `mission_send_button.dart` | 送信・クリア・定時清掃ボタンの UI |
| `schedule_dialog.dart` | 定時清掃の設定ダイアログ（時刻・曜日・予約・解除） |
| `status_notification_bar.dart` / `ble_status_indicator.dart` | 通知バー・接続状態のピル（`SelectedTabIcon` もここ） |
| `icon_tab_navigation.dart` / `polygon_form.dart` / `permission_settings_button.dart` / `frosted_glass.dart` | 小さな UI 部品 |
| `floating_action_controls.dart` | ボタンをまとめて export するだけのファイル |

### theme/

`app_strings.dart`（UI 文言。`AppNotice` の表示拡張）、`app_colors.dart`、`pill_style.dart`（状態 → ピルの見た目）。

## test/

テスト対象と同じ名前のファイルに `_test.dart` を付けた構成。`widget_test.dart` は座標変換・モデル・アプリ起動の総合テスト（地図定数の期待値を含む）。DB を使うテストは `sqflite_common_ffi` を使う。
