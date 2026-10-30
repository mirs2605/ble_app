# 引き継ぎ: 定時清掃の予定（スマホ ⇄ ロボット同期）

別の AI ツール（Antigravity 等）が、ここから作業を続けるための資料。
作成時点: 2026-10-30。BLE の PC シミュレーション環境の引き継ぎは別資料 [handoff-antigravity.md](handoff-antigravity.md) にある（今回の作業とは別件）。

## 0. 先に守ること

- 回答・説明は**日本語**で書く（コード中の識別子やコマンドは原文のまま）。
- ブランチ運用は [AGENTS.md](../AGENTS.md) に従う。`main` へ直 commit・直 push しない。1コミット1話題。push 前に `flutter analyze` と `flutter test` を通す。
- **設計者の方針: アプリとロボットの接続は BLE のみ。HTTP の受信ノードや送信モードは作らない。**
- **`ble_server` は Bluetooth サーバー単体の機能だけを持たせる**（ユーザーの指示）。予定の保持・時刻の判定を `ble_server` に入れない。責任を分離する。
- `ble_server` と `coverage` はチームのリポジトリ。ご本人の確認なしに変更・push しない。
- `sudo` や管理者権限が要る操作はご本人にやってもらう。

## 1. 何を作っているか

「自動掃除ロボットのように、一定の時刻になったら草刈り（清掃）を開始する」機能。

要件（ユーザーの決定）:

| 項目 | 決定 |
|---|---|
| 時刻の判定・開始を動かす場所 | **ロボット側**（アプリを閉じていても、スマホが圏外でも動く） |
| 予定の保存先 | **スマホとロボットの両方がデータベースを持ち、相互に同期する** |
| 予定の数 | **複数件** |
| 食い違いの扱い | **更新番号（`revision`）が大きい方を採用**。同じ番号で内容が違えばロボットを正とする |
| 今回の作成範囲 | **アプリ側のみ**。ロボット側は契約案を文書化して渡す |

## 2. 責任分担

| 担当 | 責任 | しないこと |
|---|---|---|
| アプリ（このリポジトリ） | スマホの SQLite に予定を持つ。接続のたびにロボットと同期する | 時刻の判定、清掃の開始 |
| `ble_server`（mirs2605/ble_server） | 受信した JSON を検証して ROS のサービスへ渡し、結果を Response に載せて返す | 予定の保持、時刻の判定 |
| スケジューラ（**新規ノード・未実装**。置き場所はチームで決める） | ロボット側の DB を持つ。`upsert` / 一覧取得に応じ、時刻になったら `/cleaning_zone` に publish する | BLE の扱い |

```
アプリ(SQLite) ──BLE──▶ ble_server ──ROSサービス──▶ スケジューラ(DB) ──/cleaning_zone──▶ coverage_bridge ─▶ Nav2
        ◀─────Response(JSON)───────┘
```

`/cleaning_zone` 以降（`coverage_bridge` → Nav2 → `coverage_server`）は既存のまま使う。

## 3. 現在の状態

### 3-1. ブランチと PR

- ブランチ: `feature/decouple-connection`
- PR: [mirs2605/ble_app#11](https://github.com/mirs2605/ble_app/pull/11)（作成済み。コミット `0b2ff24` 「Add scheduled cleaning reservation」まで反映）
- **未コミット**: 「1件のみ → 複数件・双方向同期」に作り直し、疎結合化リファクタリング（`ScheduleCoordinator` 分離）を行った分。コミット・push はご本人の確認待ち。
  - コミット時の注意: `docs/handoff-antigravity.md` は今回の変更と無関係の未追跡ファイル。`git add` は変更ファイルを名指しで行い、混ぜない。
- `flutter analyze`: 指摘なし。`flutter test`: **107件成功**（作業の最後に確認）。
- **実機・画面での動作確認はしていない。ロボット側は未実装。**

### 3-2. PR #11 の初版からの変更

初版は「予定1件を片方向に送る」契約（`cleaning_schedule` / `cleaning_schedule_cancel`）だった。未コミット分で次のように置き換えた。ロボット側は何も実装していないので、互換性の問題はない。

- 削除: `lib/models/cleaning_schedule.dart`、`test/cleaning_schedule_test.dart`（`git rm` 済み）
- 追加: `schedule_entry.dart`、`schedule_repository.dart`、`schedule_sync.dart`、`schedule_coordinator.dart`、テスト3本
- 書き換え: `schedule_dialog.dart`（単発の予約 → 一覧・追加・切替・削除・同期）、`ble_home_controller.dart`（facade に徹し予定ロジックを Coordinator へ委譲）、`main.dart`、`ble_service.dart` ほか

### 3-3. 実装の地図

| 役割 | ファイル |
|---|---|
| 予定1件のモデル（検証・JSON・SQLite 行への往復） | `lib/models/schedule_entry.dart` |
| スマホの DB（`schedules.db`。墓標も保持） | `lib/services/schedule_repository.dart` |
| マージ規則（`planScheduleSync`＝純粋関数）と同期の実行（`ScheduleSyncService`） | `lib/services/schedule_sync.dart` |
| 予定の管理・双方向同期・画面窓口提供の協調役 | `lib/controllers/schedule_coordinator.dart` |
| BLE の取得・送信 | `BleConnection.pullSchedules` / `pushSchedule`（`lib/services/ble_connection.dart`）、実装は `BleService`（`lib/services/ble_service.dart`） |
| 配線・画面 facade（BLE・地図・選択・時限表示・予定調停） | `lib/controllers/ble_home_controller.dart` |
| 画面 | 地図タブ下部中央の時計ボタン → `lib/widgets/schedule_dialog.dart`（`ScheduleDialogHost` で Controller と疎結合） |
| 文言・通知 | `lib/theme/app_strings.dart`、`lib/models/app_notice.dart` |
| テスト | `test/schedule_sync_test.dart`、`test/schedule_dialog_test.dart`、`test/schedule_coordinator_test.dart` |
| BLE 契約（ロボット側チームに渡す資料） | [schedule-contract.md](schedule-contract.md) |
| プロジェクトマップ | `docs/project-map/ARCHITECTURE.md`、`MODULES.md`（予定の節を追記済み） |

## 4. 契約の要点（詳細は [schedule-contract.md](schedule-contract.md)）

予定1件（record）:

```json
{"id":"9f2c41d07a3b4e85a1c6b2d3e4f50718","revision":3,"deleted":false,"enabled":true,
 "frame_id":"map","time":"09:30","weekdays":[1,3,5],
 "polygon":[{"x":1.0,"y":1.0},{"x":4.0,"y":1.0},{"x":4.0,"y":3.0},{"x":1.0,"y":3.0},{"x":1.0,"y":1.0}]}
```

- `weekdays` は 1=月〜7=日。`time` は `HH:MM`（ロボットのローカル時刻）。`polygon` は閉路（既存の `cleaning_zone` と同じ検証）。
- **削除は行を消さず `deleted: true` にして `revision` を進める（墓標）。** 消すと、相手に残った古い行が復活するため。墓標は `time` / `weekdays` / `polygon` を省略してよい。
- `schedule_upsert`（アプリ → ロボット）: ロボットは手元の `revision` より**大きいときだけ**上書きする。応答は `ACK` / `NACK`。
- `schedule_pull`（取得）: Mission へ `{"type":"schedule_pull","index":i}` を書き込み、Response を読むと `{"count":C,"index":i,"item":{record}}` が返る。**1件ずつ**（BLE の1回の読み取りは約512 bytes まで）。`count` は墓標を含む全件数。0件なら `item` なし。
- **新しい Characteristic は増やさない。** `schedule_pull` への応答だけ Response が `ACK` ではなく JSON になる。
- 予定は最大32件、1件のJSONは500 bytes 未満。

同期（アプリ側）: 接続が確立した直後、予定を変更したとき、同期ボタンを押したときに、`pull` → `revision` を比較 → スマホ側を更新 → ロボットへ `upsert`。途中で失敗しても、スマホ側の保存は残り、次回は続きから揃う。

## 5. 残っていること（次にやること）

アプリ側（このリポジトリ）:

1. 未コミット分をご本人に確認のうえコミットし、PR #11 のブランチへ push する。PR の本文は初版の記述（「1件のみ」「`cleaning_schedule`」）のままなので、**複数件・双方向同期に書き直す**。
2. 実機で画面を確認する（時計ボタン、ダイアログ、未接続での追加→接続後の自動同期）。
3. 範囲の編集 UI は未対応（削除して追加し直す）。`revision` の仕組みは編集に対応済みで、画面だけ未対応。

ロボット側（チームのリポジトリ。ご本人の確認が先）:

1. スケジューラノードを作る: DB を持つ、`upsert` / 一覧取得の ROS サービスを提供する、時刻になったら `/cleaning_zone`（PolygonStamped）に publish する。
2. `ble_server` に `schedule_upsert` / `schedule_pull` の中継を足す（DB・時刻判定は入れない）。Response に JSON を載せる経路が必要。
3. 次の点をチームで決める（契約書に未決として記載）:
   - 墓標を捨てる時期（捨てると、その間に同期しなかったスマホの古い行が復活しうる）
   - 時刻の基準（ロボットの時計・タイムゾーン。WSL シミュレーションでは PC の時計）
   - 時刻に走行中・充電中・Nav2 未起動だった場合の扱い（スキップか、遅れて開始か）
   - 実行したことをアプリへ返すか（backlog #12 の走行ステータス受信と合わせて検討）
   - 座標の丸め（float32 で保存するとスマホの値が微小に変わる。同期は収束する）

## 6. 環境

- 作業 PC: Windows 11（Git Bash と PowerShell が使える）。
- Flutter SDK: `C:\Users\kurea\flutter\bin`（PATH に入っていない）。PowerShell は `$env:Path = "C:\Users\kurea\flutter\bin;$env:Path"`、Git Bash は `export PATH="/c/Users/kurea/flutter/bin:$PATH"`。
- 検証コマンド: `flutter analyze` と `flutter test`（CI も同じ）。

## 7. 落とし穴（今回の作業で踏んだもの）

- **多くのファイルが CRLF 改行。** Python などで文字列置換するときは、`\r\n` を `\n` に直してから置換し、書き戻すときに戻す。そうしないと複数行の検索が一致しない。
- Git Bash のヒアドキュメント内に複雑なクォートを含む Python を書くと壊れることがある。長い処理はスクリプトファイルに書いて実行する。
- **`sqflite_common_ffi` のメモリ DB（`inMemoryDatabasePath`）は、既定で単一インスタンス**。同じパスで別の DB を開くと、すでに開いている DB（地図 DB）が返り、`close()` すると地図 DB まで閉じる。`ScheduleRepository.open(singleInstance: false)` でテストごとに分離している。
- `dart format` は触ったファイルだけに限定する（フォルダごとかけると無関係なファイルまで書き換わる）。
- `BleHomeController` の接続状態は、`FakeBleConnection.emit(BleStatus.connected)` を呼ぶまで更新されない（テストで接続済みにしたいときは `emit` する）。
- 接続確立の検知は `_linkUp` で行っている。送信中は `connected` と `sending` を行き来するため、`_status` の変化だけで同期を起動すると無限ループになる。

## 8. 関連資料

- [schedule-contract.md](schedule-contract.md): ロボット側チームに渡す BLE 契約案（責任分担・JSON・同期手順・未決事項）
- [project-map/INDEX.md](project-map/INDEX.md)、[ARCHITECTURE.md](project-map/ARCHITECTURE.md)、[MODULES.md](project-map/MODULES.md)
- [handoff-antigravity.md](handoff-antigravity.md): BLE の PC シミュレーション環境づくり（別件）
- [backlog.md](backlog.md): 残件（#12 走行ステータスの受信表示は予定機能と関連）
