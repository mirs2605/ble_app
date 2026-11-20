# 定時清掃の予定 — スマホ ⇄ ロボット同期の BLE 契約案

状態: **アプリ側は実装済み。ロボット側は未実装**（この契約に沿った実装が必要）。

## 方針

- 予定は **スマホとロボットの両方がデータベースに持つ**。どちらで編集しても、接続すると互いに揃う。
- 予定は **複数件**。1件ごとに ID・更新番号（`revision`）を持つ。
- 食い違ったら **`revision` が大きい方を採用**する。時計の差に左右されない。

## 責任分担

| 担当 | 責任 | しないこと |
|---|---|---|
| アプリ | スマホの DB（SQLite）に予定を持つ。接続のたびにロボットと同期する | 時刻の判定、清掃の開始 |
| `ble_server` | 受信した JSON を検証して ROS のサービスへ渡し、結果を Response に載せて返す | 予定の保持、時刻の判定（Bluetooth の入口に徹する） |
| スケジューラ（新規ノード。置き場所はチームで決める） | ロボット側の DB を持つ。`upsert` / 一覧取得に応じ、時刻になったら `/cleaning_zone` に publish する | BLE の扱い |

```
アプリ(SQLite) ──BLE──▶ ble_server ──ROSサービス──▶ スケジューラ(DB) ──/cleaning_zone──▶ coverage_bridge ─▶ Nav2
        ◀─────Response(JSON)───────┘
```

既存の `/cleaning_zone` 以降はそのまま使う。スケジューラは「人の代わりに範囲を送る」だけの役。

## 予定1件の形（record）

```json
{
  "id": "9f2c41d07a3b4e85a1c6b2d3e4f50718",
  "revision": 3,
  "deleted": false,
  "enabled": true,
  "frame_id": "map",
  "time": "09:30",
  "weekdays": [1, 3, 5],
  "polygon": [{"x":1.0,"y":1.0}, {"x":4.0,"y":1.0}, {"x":4.0,"y":3.0}, {"x":1.0,"y":3.0}, {"x":1.0,"y":1.0}]
}
```

| 項目 | 意味 |
|---|---|
| `id` | 予定の識別子。アプリが 128bit 乱数の16進で作る（1〜64文字）。端末をまたいで衝突しない |
| `revision` | 更新番号。新規は `1`。編集・有効無効の切替・削除のたびに `+1` |
| `deleted` | `true` なら削除済み（墓標）。下記参照 |
| `enabled` | `false` なら時刻になっても実行しない |
| `time` | `HH:MM`（24時間制、ロボットのローカル時刻） |
| `weekdays` | 1=月 〜 7=日（ISO 8601）。昇順・重複なし・空は不可 |
| `polygon` | `cleaning_zone` と同じ。閉路（末尾=始点）、検証ルールも同じ |

**削除は行を消さず `deleted: true` にして `revision` を進める（墓標）。** 行を消すと、相手側に残った古い行が次の同期で復活するため。墓標は `deleted: true` の場合に限り、`time` / `weekdays` / `polygon` を省略してよい（`id` と `revision` は必須）。墓標をいつ捨てるかは未決（下記）。

## 送受信 JSON

既存と同じ流儀（JSON + LF 区切り、書き込みは最大 4096 bytes）。

### 1. 反映（アプリ → ロボット）`type: schedule_upsert`

```json
{"type": "schedule_upsert", "id": "…", "revision": 3, "deleted": false, "enabled": true, "frame_id": "map", "time": "09:30", "weekdays": [1,3,5], "polygon": [ … ]}
```

- ロボットは、保持している同じ `id` の `revision` より **大きい**ときだけ上書きする。
- Response は `ACK`（採用した。すでに同じ `revision` で同じ内容だった場合も `ACK`）。`NACK` は検証エラー。
- 手元の `revision` の方が大きかった場合は `ACK` を返し、中身は変えない（アプリは次の取得で最新を知る）。

### 2. 一覧の取得（ロボット → アプリ）`type: schedule_pull`

1件ずつ取得する。BLE の読み取りは 1 回あたり最大約 512 bytes なので、まとめて返さない。

```
アプリ → Mission へ書き込み : {"type": "schedule_pull", "index": 0}
アプリ ← Response を読む     : {"count": 2, "index": 0, "item": { …record… }}
アプリ → Mission へ書き込み : {"type": "schedule_pull", "index": 1}
アプリ ← Response を読む     : {"count": 2, "index": 1, "item": { …record… }}
```

- `count` はロボットが持つ全件数（**墓標を含む**）。`index` は 0 始まり。件数 0 なら `{"count": 0, "index": 0}`（`item` なし）。
- `index` が範囲外のときは `item` を付けない。
- 順序は `index` の間で変わらないこと（取得の途中で並びが変わると取りこぼす）。同期は接続直後に行うので、走行中の更新との競合は稀。
- **Response Characteristic の使い方が変わる**: 通常は `ACK` / `NACK` だが、`schedule_pull` への応答だけは上の JSON を返す。新しい Characteristic は増やさない。
- 1件の JSON は 500 bytes 未満に収めること（頂点 6 点で約 350 bytes）。上限は予定 32 件。

## 同期のアルゴリズム（アプリ側）

接続が確立した直後と、予定を変更したとき、画面の同期ボタンを押したときに実行する。

1. `schedule_pull` でロボットの全件を取得する。
2. 予定ごとに `revision` を比べる。
   - ロボットにだけある → スマホに保存する。
   - スマホにだけある → ロボットへ `schedule_upsert` する。
   - 両方にある → `revision` が大きい方を採用する（小さい側を上書き）。
   - `revision` が同じで内容が違う → **ロボットを正**とし、スマホを置き換える（別のスマホが同時に編集した場合など）。
3. 途中で失敗しても、スマホ側の保存は残る。次回の同期で同じ計画になり、続きから揃う。

オフライン（未接続）で編集した予定は、スマホの DB に保存され、次に接続したときにロボットへ届く。

## ロボット側の実装で決めてほしいこと（未決）

- **墓標を捨てる時期**。アプリは今は捨てない。ロボットが一定期間（例: 30日）後に捨てる場合、その間に一度も同期しなかったスマホの古い行が復活しうる。
- 時刻の基準（ロボットの時計・タイムゾーン。WSL シミュレーションでは PC の時計）。
- 時刻に、走行中・充電中・Nav2 未起動だった場合の扱い（スキップするか、遅れて開始するか）。
- 実行したことをアプリへ返すか（`/coverage/state` の受信表示 backlog #12 と合わせて検討）。
- 浮動小数点（座標）の丸め。ロボットが float32 で保存して返すと、スマホの値と微小にずれる。同期は `revision` が同じで内容が違えば「ロボットを正」とするので収束するが、スマホ側の値が丸められる。

## アプリ側の実装

- モデル: `lib/models/schedule_entry.dart`
- スマホの DB: `lib/services/schedule_repository.dart`（`schedules.db`。墓標も保持）
- 同期: `lib/services/schedule_sync.dart`（`planScheduleSync` はマージ規則だけの純粋関数）
- BLE: `BleConnection.pullSchedules` / `pushSchedule`（`BleService` が `_sendJson` で送り、応答を読む）
- 配線: `BleHomeController`（追加・切替・削除・同期、接続直後の自動同期）
- 画面: 地図タブ下部中央の時計ボタン → `lib/widgets/schedule_dialog.dart`（一覧・有効切替・削除・追加・同期）
- テスト: `test/schedule_sync_test.dart`、`test/schedule_dialog_test.dart`
- 範囲は編集できない（範囲を変えたいときは削除して追加し直す）。`revision` の仕組みは編集に対応済みで、画面だけ未対応。
