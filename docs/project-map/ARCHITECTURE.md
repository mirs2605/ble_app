# Architecture

## レイヤー

```
main.dart
  └─ BleHomePage ──(ChangeNotifier を listen)── BleHomeController   … facade（配線と公開状態のみ）
        │                                         ├─ BleConnection（抽象）
        │                                         │    ├─ BleService ── BleAdapter（抽象）── FlutterBluePlusAdapter
        │                                         │    └─ PcSimulationConnection（HTTP → 127.0.0.1:8765）
        │                                         ├─ PermissionGateway
        │                                         ├─ SendMissionTracker（送信ボタン状態）
        │                                         ├─ NoticeBoard<String/AppNotice>（時限表示）
        │                                         ├─ MapSelectionController / InitialPoseController
        │                                         └─ MapConfigRepository（SQLite シングルトン）
        └─ widgets/（BleHomeTab・BleValuesTab・BleLogsTab・IconTabNavigation ほか）
models/ … 純粋なデータ・検証・座標変換（Flutter UI への依存は map_geometry の Offset/Size のみ）
theme/  … 文言・色・ピル表示の一元定義
```

- テストしやすくするための設計: Controller は `BleConnection` と `PermissionGateway` だけに依存し、テストでは Fake に差し替える。`BleService` も `BleAdapter` に依存するため、実機なしでテストできる。

## 主要な処理の流れ

### 起動

1. `main()` → `MapConfigRepository.init()`（SQLite を開く）→ `SIMULATION_MODE` を読む。
2. `BleHomeController` 生成時に接続オブジェクトを作り（シミュレーション時は `PcSimulationConnection.new`）、権限の確認と自動接続を始め、地図設定を読み込む。

### 清掃範囲の送信

1. `MapSelectionArea` でタップ → `MapSelectionController` が頂点を保持（6点で確定。`MapGeometry.freehandPolygonVertexCount`）。
2. 画面座標 ⇄ 地図座標（m）の変換は `MapGeometry`（`MapConfig` の resolution / origin を使用）。
3. `BleHomeController.setSelectedMapPoints` → `canSendPolygon` で検証 → 送信ボタンが有効になる。
4. 送信: `BleHomeController` → `BleConnection.sendCleaningZone(CleaningZoneMission)`。
   - JSON の内容: `{"type":"cleaning_zone","frame_id":"map","polygon":[...]}`。ポリゴンは**閉路**（末尾の点＝始点）。
   - BLE: MTU を調整 → `BlePayloadChunker` で分割して Mission Characteristic（`...abd`）へ書き込む → Response Characteristic（`...abe`）を読み、`ACK` なら成功、`NACK` なら失敗。
   - シミュレーション: `POST http://127.0.0.1:8765/cleaning_zone`（adb reverse 経由）。
5. 結果を `SendMissionTracker` が `SendButtonState` に反映し、通知バーとログに表示する。

### 開始地点の送信

- `MapEditMode` を pose に切り替え → `InitialPoseController` → `InitialPoseMission`（`type: initial_pose`）→ `sendInitialPose`。シミュレーションでは `/initial_pose` に送られ、ROS の `/initialpose` に publish される。

### ROS 2 側（ros2_ws、参考）

- 実機: ロボット上の `ble_server`（別リポジトリ）が `/cleaning_zone`（PolygonStamped）を publish する。
- シミュレーション: `http_gateway.py` が HTTP を受け取り、`/cleaning_zone` と `/initialpose` に publish する。
- `coverage_preview.py` が OpenNav Coverage の action を呼び、`/coverage/path` と `/coverage/state` を publish する（RViz で表示。走行はしない）。
