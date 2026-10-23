---
name: project-map
description: docs/project-map/ のプロジェクトマップを初回作成、または差分だけ更新する。構造変更・公開API変更・送信契約変更の後や、マップと実装の食い違いに気づいたときに使う。
---

# プロジェクトマップの更新

対象: `docs/project-map/INDEX.md`, `ARCHITECTURE.md`, `MODULES.md`, `DEPENDENCIES.md`

## 手順（差分更新。通常はこちら）

1. INDEX.md 冒頭の「最終確認」にあるコミットを基準にする。
2. `git diff --stat <基準コミット>..HEAD -- lib test ros2_ws pubspec.yaml` と `git status --short` で変更されたファイルを調べる。
3. 変更されたファイルだけを確認する。全文は読まず、まず import と型・公開メソッドの宣言を見る:
   - `grep -nE "^import '" <file>`
   - `grep -nE "^(abstract |sealed |final )*(class|enum|mixin|typedef|extension) " <file>`
4. 次のどれかに当てはまるものだけをマップに反映する:
   - ファイルの追加・削除・改名、役割の変化 → MODULES.md と INDEX.md の「作業別の入口」
   - 依存方向・抽象インターフェース・送信契約（JSON / UUID / HTTP パス）の変化 → DEPENDENCIES.md・ARCHITECTURE.md
   - 処理の流れの変化 → ARCHITECTURE.md
5. 変更のないファイルとセクションには手を付けない。行数の目安は、大きく変わったときだけ直す。
6. INDEX.md の「最終確認」の日付とコミットを更新する。
7. 更新した箇所と、確認できずに「未確認」と書いた箇所を報告する。

## 初回作成・作り直し

- `git ls-files` で構成をつかむ。`build/`, `.dart_tool/`, `android/`, `assets/`, `pubspec.lock` は除外する。
- 各ファイルについて import と宣言を抽出し、依存関係を組み立てる。読むのは大きいファイルや中心になるファイルの要点だけにする。
- README・AGENTS.md・docs/ の既存資料と照合する。

## 書き方のルール

- ファイル名を並べるだけにせず、「役割」「どこから読むか」「変えたら何に影響するか」を書く。
- ソースコードは書き写さない。各ファイルは1行の説明にとどめる。
- 実装を確認していない内容は「未確認」と書く。
- マップと実装が食い違う場合は、実装に合わせてマップを直す。
