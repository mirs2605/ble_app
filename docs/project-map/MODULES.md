# Modules

行数は目安（2026-10-23・main 時点）。★ は大きめのファイルで、該当箇所を検索してから部分的に読むこと。

## lib/

| ファイル | 役割 |
|---|---|
| `main.dart` | 起動、`MirsBleApp`（ダーク テーマ）、`BleHomePage`（Controller を生成し、タブを組み立てる） |

### controllers/

| ファイル | 役割 |
|---|---|
| `ble_home_controller.dart` ★340 | 画面の facade。接続状態・権限・地図・選択・送信・ログ・通知を公開する |
| `schedule_coordinator.dart` | 定時清掃の予定管理と同期の協調役。SQLite永続化・BLE同期・ダイアログへの窓口提供 |
| `robot_map_receiver.dart` | ロボットの SLAM 地図を BLE で受け取って登録する協調役（情報→分割受信→PNG化→寸法検証→保存→登録、進捗）。契約は [../map-transfer-contract.md](../map-transfer-contract.md) |
| `send_mission_tracker.dart` | 送信の進行状況 → `SendButtonState` |
| `notice_board.dart` | 一定時間だけ値を表示する汎用ボード（`TimerScheduler` を注入可能） |

### models/

| ファイル | 役割 |
|---|---|
| `schedule_entry.dart` | `ScheduleEntry`（定時清掃の予定1件。id・revision・deleted を持ち、JSON / SQLite の行へ往復。検証）。契約は [../schedule-contract.md](../schedule-contract.md) |
| `robot_map.dart` | `RobotMapInfo`（ロボットが渡す地図の説明。検証）と `crc32` |
| `cleaning_zone.dart` | `MapPoint`、`CleaningZoneMission`（JSON 化。閉路に変換。座標の範囲・頂点数（3点以上）・frame_id を検証） |
| `initial_pose.dart` | `InitialPoseMission`（x, y, theta の JSON と検証） |
| `map_config.dart` | `MapConfig`（画像・解像度・原点）、`BuiltinMaps`（学生玄関・MIRS の組み込み地図） |
| `map_geometry.dart` | 画面 ⇄ 地図座標の変換、四角形の生成（`rectangleFrom` / `rectangleFromPath`）、旧来の互換用の既定値 |
| `map_edit_mode.dart` / `send_button_state.dart` / `app_notice.dart` | 状態を表す enum |

### services/

| ファイル | 役割 |
|---|---|
| `ble_connection.dart` | `BleStatus`、抽象 `BleConnection`、`BleConnectionFactory` |
| `schedule_repository.dart` / `schedule_sync.dart` | 予定の SQLite 永続化（墓標も保持）／ロボットとの同期（`planScheduleSync` は revision で採用側を決める純粋関数） |
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
| `schedule_dialog.dart` | 予定一覧・追加・有効無効トグル・削除・手動同期のダイアログ（`ScheduleDialogHost` で Controller と疎結合） |
| `map_selection_area.dart` ★469 | 地図画像の表示とフリーハンド・頂点移動のジェスチャー処理 |
| `map_management_button.dart` | 地図選択・追加・削除のポップアップメニュー |
| `polygon_form.dart` | 4点の数値入力フォーム（バリデーションつき） |
| `floating_action_controls.dart` | 右下の送信・クリアボタン |
| `ble_status_indicator.dart` | Bluetooth ステータスアイコン |
| `status_notification_bar.dart` | 画面上部の時限通知バー |
| `icon_tab_navigation.dart` | 画面下部の3タブ切り替えバー |
| `dashed_rectangle_painter.dart` | 選択枠の点線描画 |

### theme/

| ファイル | 役割 |
|---|---|
| `app_colors.dart` | アプリ全体のカラーパレット定義 |
| `app_strings.dart` | アプリ内文言・ログ・ステータステキストの一元定義 |
