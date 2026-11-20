# SLAM の地図 — ロボット → スマホ転送の BLE 契約案

状態: **アプリ側は実装済み。ロボット側は未実装**（この契約に沿った実装が必要）。

SLAM で作った地図（`map_saver` の出力。`.pgm` と `.yaml`）を、BLE でスマホに渡して地図管理に登録する。
受け取った地図は、既存の「スマホから地図を追加」で登録した地図と同じように選択・削除できる。

## 方針

- 接続は BLE のみ（HTTP は使わない）。新しい Characteristic は増やさない。
- `ble_server` は Bluetooth の入口に徹する。地図ファイルの読み出しは、地図を持つ側のノード（`map_server` 等）が担う。
- 1回の読み取りは約 512 bytes までなので、**分割して**渡す。アプリが「何 bytes 目から何 bytes」を要求し、ロボットが応じる。

```
アプリ ──Mission 書き込み──▶ ble_server ──ROSサービス等──▶ 地図の持ち主
        ◀──Response(JSON)───┘
```

## 1. 地図の説明 `type: map_info`

```
アプリ → Mission へ書き込み : {"type": "map_info"}
アプリ ← Response を読む     : {"name":"1F","format":"pgm","size":160017,"width":400,"height":400,
                                "resolution":0.05,"origin_x":-10.0,"origin_y":-10.0,"crc32":3421780262}
```

| 項目 | 意味 |
|---|---|
| `name` | 地図の名前（省略可。省略時は「ロボットの地図」） |
| `format` | `png` または `pgm`。PGM はアプリが PNG に変換する |
| `size` | 地図データ全体の大きさ [bytes]。上限 4 MiB |
| `width` / `height` | 画像の寸法 [px]。上限は一辺 4096。**実際の画像と一致すること**（違うとアプリは登録しない） |
| `resolution` | map.yaml の `resolution` [m/px] |
| `origin_x` / `origin_y` | map.yaml の `origin` の x, y [m] |
| `crc32` | 地図データ全体の CRC32（省略可。付ければアプリが検証する。zlib / PNG と同じ多項式） |

- PGM は P5（バイナリ）か P2（テキスト）、最大値 255 以下。画素値はそのまま濃淡にする（白=通行可、黒=障害物、灰=未知）。
- PNG にして渡すと小さくなり、転送が速い（SLAM の地図は数十 KB になることが多い）。

## 2. 地図データ `type: map_chunk`

```
アプリ → Mission へ書き込み : {"type": "map_chunk", "offset": 0, "length": 256}
アプリ ← Response を読む     : {"offset": 0, "data": "<base64>"}
```

- `length` はアプリが最大 256 bytes を要求する（base64 で約 344 文字。JSON の枠を足しても 512 bytes に収まる）。
- ロボットは `offset` から **`length` 以下**の bytes を返す。`offset` は要求どおりに返すこと（違うとアプリは失敗とみなす）。
- 空のデータ、要求より長いデータは失敗とみなす（受信が進まず止まらなくなるため）。
- 末尾では、残りが `length` より短くてよい。アプリは `size` に達したら終了する。
- 応答が JSON でない・読めないときも失敗。途中で失敗した場合、アプリは何も登録しない。

## アプリ側の手順

1. 接続中に、地図管理ダイアログの「ロボットから地図を受信」を押す。
2. `map_info` で説明を取得する。
3. `map_chunk` を `size` に達するまで繰り返す（進捗バーを出す）。
4. `crc32` があれば検証する。
5. PGM なら PNG に変換する。画像の寸法が説明と一致するか確認する。
6. 画像をアプリ領域に保存し、地図として登録して有効にする。登録に失敗したら画像を消す。

転送時間の目安: 1往復を 50 ms とすると、PNG 20 KB で約 4 秒、PGM 160 KB で約 30 秒。

## ロボット側の実装で決めてほしいこと（未決）

- どの地図を渡すか（最新の SLAM の結果のみ、保存済みの一覧から選ぶ、など）。今は 1 枚だけを想定している。
- 地図データの読み出し元（`map_server` の出力ファイル、`/map` トピックの変換、など）。
- 転送中に地図が更新された場合の扱い（`size` と `crc32` が変わるので、アプリは検証で失敗する）。
- 一覧から選べるようにするなら、`map_info` に `index` を足す拡張が必要。

## アプリ側の実装

- 説明のモデル・CRC32: `lib/models/robot_map.dart`
- PGM → PNG 変換・PNG の寸法読み取り: `lib/services/pgm_codec.dart`
- BLE の送受信: `BleConnection.pullMapInfo` / `pullMapData`（`BleService` が `_sendJson` で実装）
- 受信の手順・進捗: `lib/controllers/robot_map_receiver.dart`
- 画面: 地図管理ダイアログの「ロボットから地図を受信」（`MapReceiveHost` 経由。`lib/widgets/map_management_button.dart`）
- テスト: `test/robot_map_receive_test.dart`
