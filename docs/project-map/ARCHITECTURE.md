# Architecture

## レイヤー

```
main.dart
  └─ BleHomePage ──(ChangeNotifier を listen)── BleHomeController   … facade（配線と公開状態のみ）
        │                                         ├─ RobotLink（抽象: 接続 + 各手順の窓口）
        │                                         │    └─ BleRobotLink（組み立てのみ）
        │                                         │         ├─ BleService（接続だけ）── BleAdapter（抽象）── FlutterBluePlusAdapter
        │                                         │         ├─ BleRequestChannel（要求1件の運搬）
        │                                         │         └─ CleaningZoneClient / ScheduleClient / RobotMapClient（手順）
        │                                         ├─ PermissionGateway
        │                                         ├─ SendMissionTracker（送信ボタン状態）
        │                                         ├─ NoticeBoard<String/AppNotice>（時限表示）
        │                                         ├─ MapSelectionController（範囲の生成・編集）
        │                                         ├─ MapCatalog（地図一覧・アクティブ地図）
        │                                         ├─ RobotMapReceiver（SLAM 地図の受信）
        │                                         ├─ LogBuffer（ログ）
        │                                         ├─ MapConfigRepository（SQLite シングルトン）
        │                                         └─ ScheduleCoordinator（予定管理・双方向同期の協調役）
        │                                              ├─ ScheduleRepository（SQLite）
        │                                              └─ ScheduleSyncService（同期プロトコル実行）
        └─ widgets/（MapSwitchTab・BleHomeTab・ScheduleTab・BleLogsTab・IconTabNavigation ほか）
models/ … 純粋なデータ・検証・座標変換（Flutter UI への依存は map_geometry の Offset/Size のみ）
theme/  … 文言・色・ピル表示の一元定義
```

- テストしやすくするための設計: Controller は `RobotLink` と `PermissionGateway` だけに依存し、テストでは Fake に差し替える。協調役には必要な窓口だけを渡す（`ScheduleSyncService` は `ScheduleTransport`、`RobotMapReceiver` は `RobotMapSource`）。`BleService` も `BleAdapter` に依存するため、実機なしでテストできる。
- 回線の扱い: 応答が届いたが中身が拒否（`NACK`）のときは送信失敗として返し、接続は保つ。書き込み・読み取りの失敗は切断して error にし、自動接続で張り直す。

## 主要な処理の流れ

### 起動

1. `main()` → `MapConfigRepository.init()`（SQLite を開く）→ `MirsBleApp` を起動。
2. `BleHomeController` 生成時に `BleService` を作り、権限を確認してから自動接続を始め、地図設定を読み込む。

### 清掃範囲の送信

1. `MapSelectionArea` で範囲を指定 → `MapSelectionController` が頂点列を保持。
   - なぞり描き: `MapGeometry.polygonFromPath`（軌跡から `vertexCount` 個の頂点の多角形を作る。頂点数はスライダーで変えられ、選択後に変えると作り直す）
   - ひな形: `ShapeTemplate.placeOn`（星などを地図中央に置く）
   - 頂点のハンドルをドラッグして調整できる（`hitHandle`）。
2. 画面座標 ⇄ 地図座標（m）の変換は `MapGeometry`（`MapConfig` の resolution / origin を使用）。
3. `BleHomeController.setSelectedMapPoints` → `canSendPolygon` で検証 → 送信ボタンが有効になる。
4. 送信: `BleHomeController` → `RobotLink.sendCleaningZone(CleaningZoneMission)` → `CleaningZoneClient` → `BleRequestChannel`。
   - JSON の内容: `{"type":"cleaning_zone","frame_id":"map","polygon":[...]}`。ポリゴンは**閉路**（末尾の点＝始点）。
   - BLE: MTU を調整 → `BlePayloadChunker` で分割して Mission Characteristic（`...abd`）へ書き込む → Response Characteristic（`...abe`）を読み、`ACK` なら成功、`NACK` なら失敗。読み取りできる Response Characteristic は接続の必須条件。
5. 結果を `SendMissionTracker` が `SendButtonState` に反映し、通知バーとログに表示する。

### 定時清掃の予定（スマホ ⇄ ロボットの同期）

- 予定はスマホの SQLite（`ScheduleRepository`）とロボットの DB の両方が持つ。複数件。食い違いは `revision` が大きい方を採用し、同じ番号で違う内容ならロボットを正とする。削除は墓標（`deleted`）で伝える。
- 予定タブ（`ScheduleTab` → `SchedulePanel`） → `ScheduleDialogHost`（`ScheduleCoordinator` が提供）→ `ScheduleCoordinator`（保存 → 接続中なら `ScheduleSyncService.sync()`）。接続が確立した直後にも自動で同期する。
- BLE: `schedule_pull`（1件ずつ取得。応答は Response Characteristic に JSON）／`schedule_upsert`（1件反映）。
- 時刻の判定と開始はロボット側のスケジューラが担う（未実装）。契約と責任分担は [../schedule-contract.md](../schedule-contract.md)。
- SLAM の地図の受信: 地図一覧タブ（`MapSwitchTab` → `MapManagementPanel`）の「ロボットから地図を受信」→ `RobotMapReceiver` が `map_info` / `map_chunk` で BLE から分割受信し、PGM は PNG に変換して地図として登録する（ロボット側は未実装）。契約は [../map-transfer-contract.md](../map-transfer-contract.md)。

### ロボット側（このリポジトリの外）

- ロボット上の `ble_server`（mirs2605/ble_server）が BLE で受信し、ROS 2 の `/cleaning_zone`（PolygonStamped）に publish する。
