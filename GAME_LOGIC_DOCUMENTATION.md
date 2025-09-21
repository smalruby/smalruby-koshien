# Smalruby甲子園 ゲームロジック実装

## 概要

この文書は、Smalruby甲子園競技システムの完全なゲームロジック実装について説明します。この実装は、AIバトルをサポートする安全で拡張性があり、包括的なゲーム実行エンジンを提供し、完全なイベントログと状態管理を備えています。

## アーキテクチャ

### コアコンポーネント

1. **BattleJob** - ゲーム実行のための非同期ジョブハンドラー (app/jobs/)
2. **GameEngine** - メインゲーム調整とバトル管理 (app/models/)
3. **AiEngine** - サンドボックス化された安全なRubyコード実行 (app/models/)
4. **TurnProcessor** - 個別ターンロジックとゲームメカニクス (app/models/)
5. **GameConstants** - ゲーム設定と定数 (app/models/concerns/)

### データモデル

- **Game** - プレイヤーAIとステータスを持つメインゲームエンティティ
- **GameRound** - 個別ラウンド（ゲームあたり2回）とプレイヤー、敵
- **GameTurn** - 個別ターン（ラウンドあたり最大50回）とイベント
- **Player** - プレイヤーの状態と位置管理
- **Enemy** - AI動作を持つ敵エンティティ
- **GameEvent** - 包括的なイベントログシステム

## ゲームフロー

### 1. ゲーム初期化

`startGame` GraphQL ミューテーションでゲームが開始されると：

```ruby
# StartGame ミューテーションが BattleJob をトリガー
BattleJob.perform_later(game.id)
```

### 2. バトル実行

```ruby
game_engine = GameEngine.new(game)
result = game_engine.execute_battle
```

**バトルフロー:**

1. 2ラウンドを順次実行
2. 各ラウンド: プレイヤー、敵、アイテムを初期化
3. ラウンドあたり最大50ターンを実行
4. ラウンド勝者を決定
5. ラウンド結果に基づいて総合勝者を計算

### 3. ラウンド初期化

各ラウンドで：

- GameRound レコードを作成
- 開始位置に2人のプレイヤーを初期化
- マップデータに基づいて敵を初期化
- ランダムなアイテム位置を生成
- ラウンドステータスを `in_progress` に設定

### 4. ターン処理

各ターンで：

1. 全てのアクティブプレイヤーのAIコードを実行
2. プレイヤーアクション（移動、アイテム使用、待機）を処理
3. 敵の状態と位置を更新
4. 衝突と相互作用を処理
5. スコアを更新し、ボーナスを適用
6. 勝利条件をチェック
7. 全てのイベントをログ記録

## AI実行エンジン

### セキュリティ機能

AiEngineは複数の安全層を持つ安全なRubyコード実行を提供します：

**サンドボックス化:**

- 危険なメソッドを除去した制限された binding
- タイムアウト保護（ターンあたり10秒）
- 例外処理とエラー分離
- メモリとリソース制限

**許可されたAPIメソッド:**

- `move_up`, `move_down`, `move_left`, `move_right`
- `use_dynamite`, `use_bomb`
- `get_player_info`, `get_enemy_info`, `get_map_info`
- `get_item_info`, `get_turn_info`
- `wait`, `log`

**AIコードの例:**

```ruby
# 現在のゲーム状態を取得
player = get_player_info
enemies = get_enemy_info
map = get_map_info

# シンプルなAIロジック
if player[:x] < 5
  move_right
elsif enemies.any? { |e| e[:x] == player[:x] && e[:y] == player[:y] }
  use_dynamite
else
  move_up
end
```

### エラーハンドリング

- **AiTimeoutError** - コード実行が制限時間を超過
- **AiSecurityError** - セキュリティポリシー違反
- **AiExecutionError** - 一般的な実行失敗

エラーが発生したプレイヤーは `timeout` としてマークされ、アクティブプレイから除外されます。

## ゲームメカニクス

### 移動システム

- **有効な移動**: 上、下、左、右
- **衝突検出**: 壁、水、境界
- **位置追跡**: 現在位置と前回位置を保存

### アイテムシステム

**利用可能なアイテム:**

- アイテム1-5: プラススコアボーナス（10、20、30、40、60ポイント）
- アイテム6-9: マイナススコアペナルティ（-10、-20、-30、-40ポイント）
- ダイナマイト: 壁や敵を破壊する爆発アイテム
- 爆弾: より強力な爆発アイテム

**アイテム収集:**

- プレイヤーがアイテム位置に移動すると自動収集
- 収集後にマップからアイテムが削除
- スコアが即座に更新

### 戦闘システム

**敵との相互作用:**

- 敵は隣接するプレイヤーを攻撃可能
- 敵ごとに設定可能な攻撃力
- 攻撃されたプレイヤーはポイントを失う（デフォルト-10）
- 敵は爆発物で破壊可能

**爆発メカニクス:**

- ダイナマイトと爆弾は爆発効果を作成
- 範囲内の破壊可能な壁を破壊
- 爆発範囲内の敵にダメージ
- 複数のプレイヤーに影響する可能性

### スコアリングシステム

**スコア源:**

- アイテム収集: +10〜+60ポイント（プラスアイテム）
- アイテムペナルティ: -10〜-40ポイント（マイナスアイテム）
- 歩行ボーナス: 5回移動ごとに+3ポイント
- ゴールボーナス: ゴール到達で+100ポイント
- 敵ダメージ: 攻撃を受けると-10ポイント

**キャラクターレベリング:**

- レベルは総スコアから計算: `(score - 1) / 20`
- レベルはプレイヤーの能力と外観に影響
- 最大レベル: 8

### 勝利条件

**ラウンド終了条件:**

1. プレイヤーがゴール位置に到達
2. 全プレイヤーが終了/タイムアウト
3. 最大ターン数に到達（50）

**総合勝者:**

1. 最も多くのラウンドに勝利したプレイヤー
2. 同点の場合、全ラウンドの総スコアが最も高いプレイヤー
3. それでも同点の場合、引き分け

## イベントログシステム

全てのゲームアクションはGameEventレコードとしてログ記録されます：

**イベントタイプ:**

- `MOVE` - プレイヤー移動
- `MOVE_BLOCKED` - 無効な移動試行
- `USE_DYNAMITE` / `USE_BOMB` - アイテム使用
- `COLLECT_ITEM` - アイテム収集
- `ENEMY_ATTACK` - 敵がプレイヤーを攻撃
- `PLAYER_COLLISION` - プレイヤー衝突
- `WALK_BONUS` - 歩行ボーナス適用
- `AI_TIMEOUT` - AI実行失敗

**イベントデータ構造:**

```ruby
{
  player: player_reference,
  event_type: "MOVE",
  event_data: {
    from: { x: 1, y: 1 },
    to: { x: 2, y: 1 },
    direction: "right"
  },
  occurred_at: timestamp
}
```

## ゲーム設定

### ゲーム定数

```ruby
# ゲーム設定
N_PLAYERS = 2
N_ROUNDS = 2
MAX_TURN = 50
TURN_DURATION = 10  # 秒

# アイテム
N_DYNAMITE = 2
N_BOMB = 2
WALK_BONUS = 3
WALK_BONUS_BOUNDARY = 5

# マップ要素
MAP_BLANK = 0
MAP_WALL1 = 1
MAP_WALL2 = 2
MAP_GOAL = 3
MAP_WATER = 4
MAP_BREAKABLE_WALL = 5
```

## API統合

### GraphQL ミューテーション

**ゲーム開始:**

```graphql
mutation($gameId: ID!) {
  startGame(gameId: $gameId) {
    game {
      id
      status
      winner
    }
    errors
  }
}
```

### ジョブ処理

ゲームはActiveJobを使用して非同期で処理されます：

```ruby
# バトルをキューに追加
BattleJob.perform_later(game_id)

# 即座に処理（テスト用）
BattleJob.perform_now(game_id)
```

## テスト

### テストカバレッジ

包括的なテストスイートがカバーする項目：

1. **GameEngine テスト** - バトル実行、ラウンド管理、勝者決定
2. **AiEngine テスト** - コード実行、セキュリティ、APIメソッド
3. **TurnProcessor テスト** - 移動、アイテム、衝突、スコア
4. **BattleJob テスト** - 非同期実行、エラーハンドリング

### テスト例

```ruby
RSpec.describe GameEngine do
  it "完全なバトルを実行する" do
    result = game_engine.execute_battle

    expect(result[:success]).to be true
    expect(result[:winner]).to be_in([:first, :second, nil])
    expect(game.game_rounds.count).to eq(2)
  end
end
```

## パフォーマンス考慮事項

### 最適化機能

1. **非同期処理** - ゲームはWebリクエストをブロックしない
2. **タイムアウト保護** - 暴走するAIコードを防ぐ
3. **メモリ管理** - サンドボックス化された実行コンテキスト
4. **データベース最適化** - includesを使用した効率的なクエリ
5. **イベントバッチング** - 効率的なイベントログ

### モニタリング

- 包括的なRailsログ
- エラー追跡とレポート
- ゲーム実行メトリクス
- AIパフォーマンス監視

## セキュリティ

### AIコードセキュリティ

1. **サンドボックス実行** - 制限されたbinding環境
2. **メソッドフィルタリング** - 危険なメソッドの除去
3. **タイムアウト保護** - 実行時間制限
4. **リソース制限** - メモリとCPU制約
5. **入力検証** - AIアクション検証

### データセキュリティ

1. **入力サニタイゼーション** - 全ユーザー入力の検証
2. **SQLインジェクション防止** - ActiveRecord保護
3. **アクセス制御** - 適切な認証/認可
4. **監査ログ** - 完全なイベント追跡

## デプロイメント

### 要件

- Ruby 3.3+
- Rails 8.0+
- PostgreSQL (JSON サポート用)
- Redis (ジョブ処理用)

### 設定

```ruby
# config/application.rb
config.autoload_paths << Rails.root.join("app", "services")

# ジョブキュー設定
config.active_job.queue_adapter = :sidekiq  # または :resque
```

## 将来の機能拡張

### 予定機能

1. **高度なAI API** - より多くのゲーム状態情報
2. **チームバトル** - マルチプレイヤーチームサポート
3. **トーナメントシステム** - ブラケット式競技
4. **リプレイシステム** - ゲーム再生機能
5. **パフォーマンス分析** - AIパフォーマンスメトリクス
6. **マップエディタ** - ビジュアルマップ作成ツール

### 拡張性

システムは簡単な拡張のために設計されています：

- 新しいAI APIメソッドをAiExecutionContextに追加可能
- TurnProcessorによる追加ゲームメカニクス
- 新機能用のカスタムイベントタイプ
- プラグ可能なスコアリングシステム
- 設定可能なゲームルール

## トラブルシューティング

### よくある問題

1. **AIタイムアウト** - コードの複雑さとループをチェック
2. **無効な移動** - マップ境界と障害物を確認
3. **イベント欠損** - TurnProcessorのイベントログを確認
4. **ジョブ失敗** - ジョブキューとエラーログを監視

### デバッグツール

```ruby
# デバッグログを有効化
Rails.logger.level = Logger::DEBUG

# 手動ゲーム実行
game_engine = GameEngine.new(game)
game_engine.execute_battle

# ゲーム状態確認
game.game_rounds.includes(:players, :enemies, game_turns: :game_events)
```

## 結論

Smalruby甲子園ゲームロジック実装は、AIプログラミング競技のための堅牢で安全、かつ拡張可能な基盤を提供します。このアーキテクチャは、セキュリティとパフォーマンスを維持しながら複雑なゲームメカニクスをサポートし、教育環境や競技プログラミングコンテストに適しています。