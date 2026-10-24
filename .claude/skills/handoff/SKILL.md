---
name: handoff
description: 作業を中断するときやセッションを切り替えるときに、現在の作業状態を docs/handoffs/current.md に短く保存する。次のセッションはこのファイルから再開する。
---

# 作業の引き継ぎ

## 手順

1. `git status --short`、`git branch --show-current`、`git log --oneline -5` で事実を集める。
2. 次の内容を集める: このセッションで実行したテストとその結果、未解決の問題、決めたこと。
3. `docs/handoffs/current.md` を下のテンプレートで**上書き**する（履歴は git が残すので、追記はしない）。
   - 30行程度に収める。
   - プロジェクトマップの内容（ファイルの役割など）は書き写さない。
   - 実行していないテストを「通過」と書かない。不明な項目は「未確認」とする。
4. 作業が完了していて引き継ぐことがなければ、テンプレートの空欄の状態に戻す。
5. コミットするかどうかはユーザーに確認する（main への直接コミットは禁止。AGENTS.md 参照）。

## テンプレート

```markdown
# Current Handoff

更新: YYYY-MM-DD / ブランチ: <branch> / HEAD: <short sha>

## Task
- 

## Completed
- 

## Changed files
- `path`: 変更内容

## Verification
- 実行したテストとその結果:

## Remaining issues
- 

## Next actions
1. 

## Important decisions
- 
```
