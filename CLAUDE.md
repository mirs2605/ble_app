# CLAUDE.md — ble_app（マツナビ / mirs_ble_app）

@AGENTS.md

## 概要

- MIRS ロボットへ清掃範囲（四角形・4点）と開始地点を BLE で送る Flutter アプリ。
- 送信は `BleService` が担い、ロボット側の `ble_server`（別リポジトリ）が受信する。

## ドキュメントの入口

- 構成の索引: [docs/project-map/INDEX.md](docs/project-map/INDEX.md)（最初はここだけ読む）
- 処理の流れ: docs/project-map/ARCHITECTURE.md
- ファイルの役割: docs/project-map/MODULES.md
- 依存と影響範囲: docs/project-map/DEPENDENCIES.md
- 作業の引き継ぎ: docs/handoffs/current.md（作業を再開するときだけ読む）
- 残件・設計判断: docs/backlog.md / docs/reviews/configuration-review.md

## 作業ルール

- 作業前に `git status` と現在のブランチを確認する。
- まず INDEX.md の「作業別の入口」で対象ファイルを絞り、関係するファイルだけを読む。`lib/` 全体をまとめて読まない。
- `build/`・`.dart_tool/`・`android/`（署名・Gradle 以外）・`pubspec.lock`・`assets/` の画像は原則として読まない。
- マップと実装が食い違うときは実装を優先し、マップを修正する。
- 確認した事実と推測を区別して報告する。
- 公開 API・依存関係・送信契約が変わったときだけ、該当するマップを更新する（`/project-map`）。
- 長い作業を中断するときは `/handoff` で引き継ぎを残す。
