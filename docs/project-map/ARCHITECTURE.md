# Architecture

## レイヤー

```
main.dart
  └─ BleHomePage ──(ChangeNotifier を listen)── BleHomeController   … facade（配線と公開状態のみ）
        │                                         ├─ BleConnection（抽象）
        │                                         │    └─ BleService ── BleAdapter（抽象）── FlutterBluePlusAdapter
        │                                         ├─ PermissionGateway
        │                                         ├─ SendMissionTracker（送信ボタン状態）
        │                                         ├─ NoticeBoard<String/AppNotice>（時限表示）
        │                                         ├─ MapSelectionController / InitialPoseController
        │                                         ├─ MapConfigRepository（SQLite シングルトン）
        │                                         └─ ScheduleCoordinator（予定管理・双方向同期の協調役）
        │                                              ├─ ScheduleRepository（SQLite）
        │                                              └─ ScheduleSyncService（同期プロトコル実行）
        └─ widgets/（BleHomeTab・BleValuesTab・BleLogsTab・IconTabNavigation ほか）
models/ … 純粋なデータ・検証・座標変換（Flutter UI への依存は map_geometry の Offset/Size のみ）
theme/  … 文言・色・ピル表示の一元定義
```

- テストしやすくするための設計: Controller は `BleConnection` と `PermissionGateway` だけに依存し、テストでは Fake に差し替える。`BleService` も `BleAdapter` に依存するため、実機なしでテストできる。

## 主要な処理の流れ

### 起動

1. `main()` → `MapConfigRepository.init()`（SQLite を開く）→ `MirsBleApp` を起動。
2. `BleHomeController` 生成時に `BleService` を作り、権限を確認してから自動接続を始め、地図設定を読み込む。

### 清掃範囲の送信

1. `MapSelectionArea` で範囲を指定 → `MapSelectionController` が4頂点を保持。
   - ドラッグ: `MapGeometry.rectangleFrom`（始点と終点から四角形）
   - なぞり描き: `MapGeometry.rectangleFromPath`（軌跡を4方向に分けて4隅を決める）
   - 頂点のハンドルをドラッグして調整できる（`hitHandle`）。
2. 画面座標 ⇄ 地図座標（m）の変換は `MapGeometry`（`MapConfig` の resolution / origin を使用）。
3. `BleHomeController.setSelectedMapPoints` → `canSendPolygon` で検証 → 送信ボタンが有効になる。
4. 送信: `BleHomeController` → `BleConnection.sendCleaningZone(CleaningZoneMission)`。
   - JSON の内容: `{"type":"cleaning_zone","frame_id":"map","polygon":[...]}`。ポリゴンは**閉路**（末尾の点＝始点）。
   - BLE: MTU を調整 → `BlePayloadChunker` で分割して Mission Characteristic（`...abd`）へ書き込む → Response Characteristic（`...abe`）を読み、`ACK` なら成功、`NACK` なら失敗。読み取りできる Response Characteristic は接続の必須条件。
5. 結果を `SendMissionTracker` が `SendButtonState` に反映し、通知バーとログに表示する。

### 開始地点の送信

- `MapEditMode` を pose に切り替え → `InitialPoseController` → `InitialPoseMission`（`type: initial_pose`）→ `sendInitialPose`。

### 定時清掃の予定（スマホ ⇄ ロボットの同期）

- 予定はスマホの SQLite（`ScheduleRepository`）とロボットの DB の両方が持つ。複数件。食い違いは `revision` が大きい方を採用し、同じ番号で違う内容ならロボットを正とする。削除は墓標（`deleted`）で伝える。
- 地図タブの時計ボタン → `ScheduleDialog` → `ScheduleDialogHost`（`ScheduleCoordinator` が提供）→ `ScheduleCoordinator`（保存 → 接続中なら `ScheduleSyncService.sync()`）。接続が確立した直後にも自動で同期する。
- BLE: `schedule_pull`（1件ずつ取得。応答は Response Characteristic に JSON）／`schedule_upsert`（1件反映）。
- 時刻の判定と開始はロボット側のスケジューラが担う（未実装）。契約と責任分担は [../schedule-contract.md](../schedule-contract.md)。
- SLAM の地図の受信: 地図管理ダイアログの「ロボットから地図を受信」→ `RobotMapReceiver` が `map_info` / `map_chunk` で BLE から分割受信し、PGM は PNG に変換して地図として登録する（ロボット側は未実装）。契約は [../map-transfer-contract.md](../map-transfer-contract.md)。

### ロボット側（このリポジトリの外）

- ロボット上の `ble_server`（mirs2605/ble_server）が BLE で受信し、ROS 2 の `/cleaning_zone`（PolygonStamped）に publish する。
