# AGENTS.md — ble_app

Flutterアプリ（清掃範囲の描画・BLE送信）。CI: `ci` ワークフロー。

## ブランチ運用

- `main` / `develop` 直commit・直push禁止。`feature/*` → `develop` → `main` のPRのみ
- 1コミット1話題。`flutter analyze` と `flutter test` を通してからpush

## テスト

```bash
flutter analyze
flutter test
```

## 注意

- 地図定数（`lib/models/map_geometry.dart`）変更時は `test/widget_test.dart` の期待値を再計算すること
- 浮動小数点の比較は `moreOrLessEquals` / `closeTo` を使う（完全一致は丸め誤差で落ちる）
