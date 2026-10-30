# 定時清掃の BLE 契約案

状態: **アプリ側は実装済み。ロボット側は未実装**（この契約に沿った実装が必要）。

## 責任分担

| 担当 | 責任 | しないこと |
|---|---|---|
| アプリ | 予定（時刻・曜日・範囲）を作り、BLE で送る。解除も送る | 時刻の判定、清掃の開始 |
| `ble_server` | 受信した JSON を検証して ROS のトピックへ publish し、`ACK` / `NACK` を返す | 予定の保持、時刻の判定（Bluetooth の入口に徹する） |
| スケジューラ（新規ノード。置き場所は coverage 側などチームで決める） | 予定を保持・永続化し、時刻になったら `/cleaning_zone` に publish する | BLE の扱い |

既存の流れ（`/cleaning_zone` → `coverage_bridge` → Nav2）はそのまま使う。スケジューラは「人の代わりに範囲を送る」だけの役。

```
アプリ ──BLE──▶ ble_server ──/cleaning_schedule──▶ スケジューラ ──/cleaning_zone──▶ coverage_bridge ─▶ Nav2
                         └─/cleaning_schedule_cancel─▶
```

## 送信 JSON

どちらも既存と同じ流儀（JSON + LF 区切り、最大 4096 bytes、`ACK` / `NACK`）。

### 予約（`type: cleaning_schedule`）

```json
{
  "type": "cleaning_schedule",
  "frame_id": "map",
  "time": "09:30",
  "weekdays": [1, 3, 5],
  "polygon": [{"x":1.0,"y":1.0}, {"x":4.0,"y":1.0}, {"x":4.0,"y":3.0}, {"x":1.0,"y":3.0}, {"x":1.0,"y":1.0}]
}
```

- `time`: `HH:MM`（24時間制、ロボットのローカル時刻）。
- `weekdays`: 1=月 〜 7=日（ISO 8601）。昇順・重複なし・空は不可。
- `polygon`: `cleaning_zone` と同じ。閉路（末尾=始点）、検証ルールも同じ。
- 予定は **1件だけ**。再度送ると上書きする（複数予定は今回の対象外）。

### 解除（`type: cleaning_schedule_cancel`）

```json
{"type": "cleaning_schedule_cancel"}
```

## ロボット側の実装で決めてほしいこと（未決）

- 予定の保存先（再起動後も残すか）。アプリは予定を読み戻せないため、残さない場合は「再起動で消える」とアプリ側で見せる必要がある。
- 時刻の基準（ロボットの時計・タイムゾーン。WSL シミュレーションでは PC の時計）。
- 時刻になったときにロボットが走行中・充電中・Nav2 未起動だった場合の扱い（スキップするか、遅れて開始するか）。
- 実行したことをアプリへ返すか（`/coverage/state` の受信表示 backlog #12 と合わせて検討）。

## アプリ側の実装

- モデル: `lib/models/cleaning_schedule.dart`
- 送信: `BleConnection.sendCleaningSchedule` / `cancelCleaningSchedule`（`BleService` が `_sendJson` で送る）
- 画面: 地図タブ下部中央の時計ボタン → `lib/widgets/schedule_dialog.dart`
- テスト: `test/cleaning_schedule_test.dart`
