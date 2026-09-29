# リファクタ残件リスト（mirs_ble_app）

P0（Controller分割・Adapter分離・SSOT化・フォーム移管）は完了済み。
本書は残件のみを扱う。広範な再リファクタは費用対効果が低いため対象外。

最終更新: 2026-09-29 / `flutter analyze` No issues / `flutter test` 63件通過

## 凡例

- 優先度: 高 = 不具合・テスト不能の温床 / 中 = 変更コストの削減 / 低 = 見た目の整理
- 工数: S < 1h / M 半日 / L 1日

---

## P1: 残件（小〜中規模）

### 1. マジックナンバー・トークンの集約 [中/M]
- `Duration(milliseconds ...)` が `lib/` に7件散在（180/220/350/650ms）。
  別途 `lib/widgets/mission_send_button.dart` に600msが1件。
  - 例: `lib/widgets/status_notification_bar.dart`（スライド350ms・切替180ms）
  - 例: `lib/widgets/ble_status_indicator.dart`（回転650ms・伸縮220ms）
- 寸法の直書き: ピル幅 44/132、通知最大幅 220、スライド量 56、
  `lib/widgets/map_selection_area.dart` の `_MapMagnifier`（直径116・間隔48・倍率1.8）、
  `lib/services/map_selection_controller.dart` のハンドル判定距離18、
  拡縮クランプ 1.0–4.0。
- 方針: `AppDurations` / `AppSizes` を新設し、`PillStyle`・`AppStrings` と同じ流儀で一元化する。
- 注意: `BleService` のタイムアウト類（8s/10s/5s/4096B）は static const 化済み。自動スキャン周期4sのみ残存。

### 2. 残存UI文言の `AppStrings` 寄せ [中/S]
- `PillStyle` 系の文言は移行済み。未移行は以下（多言語化の完成条件）。
  - `lib/widgets/icon_tab_navigation.dart`: タブ名・tooltip（数値/マップ/ログ）
  - `lib/widgets/polygon_form.dart`: `頂点 ${index + 1}`、`X (m)` / `Y (m)`
  - `lib/widgets/permission_settings_button.dart`: tooltip（権限設定を開く）
  - ※ `範囲を囲ってください` は通知バーへ移行済み（`AppNotice.encloseRange`）。
    `map_selection_area.dart` の選択完了ログ（🖐️）はログ文のため対象外でよい。
- `lib/services/ble_service.dart` の診断ログ群は開発者向けのため対象外でよい（要判断）。

### 3. 送信中フラグと実態の乖離 [中/S]
- `BleHomeController.setSelectedMapPoints` / `clearSelection` が
  `SendMissionTracker.resetProgress()` のみ折り、進行中のBLE送信自体は止まらない。
  - 現状の実害は小（`BleService` 側の `_isSending` ガードが二重送信を防ぐ）が、
    ボタン表示（ready）と実態（送信中）が一時的に食い違う。
- 方針: 選択変更時に進行中送信の完了を待つか、送信キャンセルAPIを `BleConnection` に追加する。
  - キャンセル追加は `BleAdapter` まで波及するため、まずは「選択変更で送信中は上書きしない」等の小手当てでもよい。

### 4. ファイル凝集の小整理 [低/S]
- `SelectedTabIcon` が `lib/widgets/ble_status_indicator.dart` 末尾にあるが利用者は
  `lib/widgets/icon_tab_navigation.dart` のみ。置き場所を移すか専用ファイル化。
- `lib/widgets/floating_action_controls.dart` は実態がボタンの barrel export で名前が misleading
  （`controls` → `buttons` 等への改名、または削除して直接 import）。
- import 形式の統一: 相対パス（`../models/...`）と package 形式が混在しうる。どちらかに統一する。

### 5. `analysis_options.yaml` の厳格化 [低/S]
- 現状は `flutter_lints` のデフォルトのみ。候補: 未使用要素の検出強化など。
- 注意: `public_member_api_docs` 等の doc 系ルールはノイズが大きいため非推奨。最小限の追加に留める。

---

## P2: テスト・堅牢性（任意）

### 6. 送信結果の型 [中/M]
- `BleService.sendCleaningZone` が `bool`＋ログ文字列で結果を返すため、UI が
  「再試行可能か」「入力修正が必要か」を区別できない。
- 方針: `sealed SendResult`（success / userError / retryable 等）への置換。
  - `BleConnection` インターフェース・`SendMissionTracker`・`BleHomeController.sendPolygon`・
    Fake 群・`ble_service_test.dart` まで波及する。手数はMだが影響範囲は明確。

### 7. 光学補正の回帰テスト [低/M]
- `BleStatusIndicator` の `_iconOpticalCorrection`（Offset(-0.8, -0.9)）は実測ベースだが、
  回帰テストがない（測定用の一時テストは削除済み）。
- 方針: `FontLoader` で実フォントを読み込む測定ヘルパーを恒常テストとして残す。
  - 注意: 実行が重い（数秒）・環境依存のため、通常テストとは分離（タグ分け等）推奨。

### 8. 通知バーのスライド Widget テスト [低/S]（完了 2026-09-29）
- `test/status_notification_bar_test.dart` に2件恒常化済み（伸縮・非表示時のレイアウト除外）。
  いずれも `pumpAndSettle` 前後での表示確認を含む。

---

## 新機能: 初期位置・ステータス連携（2026-09-29追加）

BLE契約（type文字列・GATT構成）は server・coverage と同時改訂が必要。全体像は `ws/TODO.md` §5。

### 11. 現在位置・向きの入力と送信 [高/M]
- 入力フォーム（x, y, theta）とモデル追加（案: `type: 'initial_pose'`＋`frame_id`＋pose のJSON）。
  - 制約は `CleaningZoneMission` と同一流儀（座標±1000、`frame_id='map'`）。
- 送信経路は `BleConnection.sendCleaningZone` と同流儀で新API追加。
  - 注意: 送信結果の型置換（#6）より先に着手する場合は `bool`＋ログの現行形式に合わせる。
- テスト: JSON契約テスト（server側の受信実装とtype文字列の一致が前提）。

### 12. 走行ステータスの受信表示 [中/M]
- read characteristic のポーリングで `/coverage/state` 文字列
  （`WAITING_NAV_SERVER` / `WAITING_NAV_RETRY n/m` / `DONE` / `CANCELED` / `FAILED` / `FAILED_INVALID_ZONE` / `FAILED_REJECTED`）を取得・表示する。
- 進捗（`distance_remaining` 等の feedback 値）を出す場合はBLEペイロード設計が別途必要（サイズ制約）。
  項目選定は server 側（`ws/TODO.md` §5.2）と合意すること。
- notify 化されたら購読方式に切替（GATT構成の変更は server 側）。

---

## プロセス

### 9. working tree のコミット [高/S]（完了 2026-09-29）
- 記載時の未コミット分はコミット済み（working tree は本書の編集中差分のみ）。
  今後も切り分けが効かなくなる前にコミットすること。
- 推奨粒度: (a) 着手前差分 (b) P0-1 (c) P0-2 (d) P0-3＋P0-4 (e) 通知バー・文言・アイコン補正

### 10. [構成レビュー](reviews/configuration-review.md)との役割分担
- BLE契約・署名・権限などの指摘は[構成レビュー](reviews/configuration-review.md)が有効。本書はアプリ層構造のみ扱う。
- 両方に手を付ける場合は、BLE契約側（実機確認が必要）とアプリ層（単体テスト可）を別スプリントに分けること。

---

## やらないこと

- 広範な再リファクタ: P0後の構造（facade＋Adapter＋SSOT＋51テスト）で十分であり、
  目視確認系の作業速度には寄与しない。
- `ble_service.dart` 診断ログの多言語化: 開発者向けのため対象外（#2 の要判断事項）。
- ゴールデンテストの導入: 現状の規模では費用対効果が低い。
