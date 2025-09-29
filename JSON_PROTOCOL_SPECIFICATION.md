# JSON Communication Protocol Specification

## 概要

この仕様は、AiProcessManagerとAIプロセス間の標準入出力を使用したJSON形式の通信プロトコルを定義します。このプロトコルにより、独立したプロセスとして実行されるAIコードと、ゲームエンジン間での安全な情報交換を実現します。

## 基本原則

### 通信方式
- **標準入力**: AiProcessManager → AIプロセス（JSON形式）
- **標準出力**: AIプロセス → AiProcessManager（JSON形式）
- **エンコーディング**: UTF-8
- **区切り文字**: 各JSONメッセージは改行文字(`\n`)で区切る

### メッセージ構造
全てのメッセージは以下の基本構造を持ちます：

```json
{
  "type": "message_type",
  "timestamp": "2025-09-24T01:30:00Z",
  "data": { /* message-specific data */ }
}
```

## 入力メッセージ (AiProcessManager → AIプロセス)

### 1. プロセス初期化メッセージ

AIプロセス起動時に送信される初期化情報：

```json
{
  "type": "initialize",
  "timestamp": "2025-09-24T01:30:00Z",
  "data": {
    "game_id": "123",
    "round_number": 1,
    "player_index": 0,
    "player_ai_id": "456",
    "rand_seed": 12345,
    "game_map": {
      "width": 15,
      "height": 15,
      "map_data": [
        [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 1, 0, 1, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      ],
      "goal_position": { "x": 14, "y": 14 }
    },
    "initial_position": { "x": 0, "y": 0 },
    "initial_items": {
      "dynamite_left": 2,
      "bomb_left": 2
    },
    "game_constants": {
      "max_turns": 50,
      "turn_timeout": 5
    }
  }
}
```

### 2. ターン開始メッセージ

各ターン開始時に送信される現在のゲーム状態：

```json
{
  "type": "turn_start",
  "timestamp": "2025-09-24T01:30:01Z",
  "data": {
    "turn_number": 1,
    "current_player": {
      "id": "789",
      "position": { "x": 0, "y": 0 },
      "previous_position": { "x": 0, "y": 0 },
      "score": 0,
      "character_level": 1,
      "dynamite_left": 2,
      "bomb_left": 2,
      "walk_bonus_counter": 0,
      "acquired_positive_items": [0, 0, 0, 0, 0, 0],
      "status": "playing"
    },
    "other_players": [
      {
        "id": "790",
        "position": { "x": 14, "y": 0 },
        "status": "playing",
        "character_level": 1
      }
    ],
    "enemies": [
      {
        "id": "801",
        "position": { "x": 7, "y": 7 },
        "previous_position": { "x": 7, "y": 6 },
        "state": "normal_state",
        "enemy_kill": "no_kill",
        "killed": false
      }
    ],
    "visible_map": {
      "width": 15,
      "height": 15,
      "map_data": [
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, "a", 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "A", 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3]
      ]
    }
  }
}
```

### 3. ターン終了確認メッセージ

AIプロセスからturn_overアクションを受信した後の確認：

```json
{
  "type": "turn_end_confirm",
  "timestamp": "2025-09-24T01:30:05Z",
  "data": {
    "turn_number": 1,
    "actions_processed": 2,
    "next_turn_will_start": true
  }
}
```

### 4. ゲーム終了メッセージ

ゲーム/ラウンド終了時に送信：

```json
{
  "type": "game_end",
  "timestamp": "2025-09-24T01:35:00Z",
  "data": {
    "reason": "goal_reached",
    "final_score": 150,
    "final_position": { "x": 14, "y": 14 },
    "round_winner": "player_1",
    "total_turns": 23
  }
}
```

## 出力メッセージ (AIプロセス → AiProcessManager)

### 1. 準備完了メッセージ

AIプロセス起動時に送信する準備完了通知：

```json
{
  "type": "ready",
  "timestamp": "2025-09-24T01:30:00Z",
  "data": {
    "player_name": "timeout_player",
    "ai_version": "1.0.0",
    "status": "initialized"
  }
}
```

### 2. ターン終了メッセージ

ターンの終了と実行するアクションを通知（最大2つのアクション）：

```json
{
  "type": "turn_over",
  "timestamp": "2025-09-24T01:30:05Z",
  "data": {
    "actions": [
      {
        "action_type": "move",
        "direction": "right"
      },
      {
        "action_type": "explore",
        "target_position": { "x": 5, "y": 5 },
        "area_size": 5
      }
    ]
  }
}
```

#### アクション例

##### 移動アクション（方向指定）
```json
{
  "action_type": "move",
  "direction": "up"
}
```

##### 移動アクション（座標指定）
```json
{
  "action_type": "move",
  "target_x": 1,
  "target_y": 2
}
```

##### アイテム使用アクション
```json
{
  "action_type": "use_item",
  "item": "dynamite",
  "position": { "x": 2, "y": 3 }
}
```

##### 探索アクション
```json
{
  "action_type": "explore",
  "target_position": { "x": 5, "y": 5 },
  "area_size": 5
}
```

### 3. デバッグメッセージ

デバッグ情報の出力：

```json
{
  "type": "debug",
  "timestamp": "2025-09-24T01:30:02Z",
  "data": {
    "level": "info",
    "message": "同じ場所を探索中: 0:0",
    "context": {
      "current_action": "explore",
      "turn_number": 1
    }
  }
}
```

### 4. エラーメッセージ

実行時エラーの報告：

```json
{
  "type": "error",
  "timestamp": "2025-09-24T01:30:03Z",
  "data": {
    "error_type": "invalid_move",
    "message": "指定された座標(15, 15)はマップ範囲外です",
    "details": {
      "attempted_position": { "x": 15, "y": 15 },
      "map_bounds": { "width": 15, "height": 15 }
    }
  }
}
```

## プロトコルライフサイクル

### 1. 初期化フェーズ

```
AiProcessManager → AIプロセス: initialize メッセージ
AIプロセス → AiProcessManager: ready メッセージ
```

### 2. ゲームループ

```
ゲームループ（最大50ターン）:
  AiProcessManager → AIプロセス: turn_start メッセージ

  AIプロセス処理:
    AIプロセス → AiProcessManager: debug メッセージ (任意)
    AIプロセス → AiProcessManager: turn_over メッセージ (最大2つのアクションを含む)

  AiProcessManager → AIプロセス: turn_end_confirm メッセージ
```

### 3. 終了フェーズ

```
AiProcessManager → AIプロセス: game_end メッセージ
AIプロセス終了
```

## エラーハンドリング

### タイムアウト処理

AIプロセスが5秒間出力を行わない場合：

1. AiEngineがプロセスを強制終了
2. プレイヤーのステータスを`timeout`に変更
3. ゲームから除外

### 無効なJSON

不正なJSON形式を受信した場合：

1. エラーログを記録
2. そのメッセージを無視
3. 処理を継続

### 無効なアクション

実行不可能なアクションを受信した場合：

1. 無効なアクションを無視
2. そのターンは何も実行しない
3. エラーログを記録

## データ型仕様

### 座標
```json
{ "x": integer, "y": integer }
```

### アクションタイプ
- `"move"`: 移動
- `"use_item"`: アイテム使用
- `"explore"`: 探索

### アイテムタイプ
- `"dynamite"`: ダイナマイト
- `"bomb"`: 爆弾

### 移動方向
- `"up"`: 上
- `"down"`: 下
- `"left"`: 左
- `"right"`: 右

### プレイヤーステータス
- `"playing"`: プレイ中
- `"completed"`: ゴール到達または敵に倒された
- `"timeout"`: AIタイムアウト
- `"timeup"`: 制限時間切れ

### 敵ステータス
- `"normal_state"`: 通常状態
- `"angry"`: 怒りモード
- `"kill"`: やられるぞモード
- `"done"`: 撃退済み

## 実装例

### Stage 1（タイムアウト）の通信例

```
AiProcessManager → AIプロセス:
{
  "type": "initialize",
  "data": { /* 初期化データ */ }
}

AIプロセス → AiProcessManager:
{
  "type": "ready",
  "data": { "player_name": "timeout_player" }
}

AiProcessManager → AIプロセス:
{
  "type": "turn_start",
  "data": { "turn_number": 1, /* ゲーム状態 */ }
}

// AIプロセスは何も出力しない（タイムアウト）

5秒後:
AiProcessManagerがプロセス強制終了
```

### Stage 3（水平移動）の通信例

```
// ターン1（右に移動）
AiProcessManager → AIプロセス: turn_start (turn_number: 1)

AIプロセス → AiProcessManager:
{
  "type": "turn_over",
  "data": {
    "actions": [
      { "action_type": "move", "direction": "right" }
    ]
  }
}

// ターン2（左に移動）
AiProcessManager → AIプロセス: turn_start (turn_number: 2)

AIプロセス → AiProcessManager:
{
  "type": "turn_over",
  "data": {
    "actions": [
      { "action_type": "move", "direction": "left" }
    ]
  }
}
```

## セキュリティ考慮事項

### 入力検証
- JSON形式の妥当性チェック
- データタイプの検証
- 範囲チェック（座標、値の上限下限）

### リソース制限
- メッセージサイズ制限（最大1MB）
- 1ターンあたりのメッセージ数制限（最大100メッセージ）
- メモリ使用量監視

### プロセス分離
- 独立したプロセス空間での実行
- ファイルシステムアクセス制限
- ネットワークアクセス制限

## 拡張性

このプロトコルは以下の拡張に対応できるよう設計されています：

1. **新しいアクションタイプ**: `action_type`フィールドに新しい値を追加
2. **追加のゲーム状態**: `turn_start`メッセージの`data`フィールドに新しい情報を追加
3. **カスタムメッセージタイプ**: 新しい`type`値の定義
4. **バージョニング**: メッセージにプロトコルバージョンフィールドを追加可能

## 実装ガイドライン

### AiProcessManager側実装
1. JSON生成・パース機能
2. プロセス管理（起動・停止・監視）
3. タイムアウト管理
4. エラーハンドリング

### AIプロセス側実装
1. 標準入力からのJSON読み取り
2. 標準出力へのJSON書き込み
3. Koshien APIメソッドのプロトコル変換
4. 適切なエラーレポート

この仕様により、安全で拡張可能、かつデバッグしやすいAI実行環境を実現します。