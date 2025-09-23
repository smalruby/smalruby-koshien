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
- **Player** - プレイヤーの状態と位置管理（HPシステム除去済み）
- **Enemy** - AI動作を持つ敵エンティティ（HPシステム除去済み）
- **GameEvent** - 包括的なイベントログシステム
- **PlayerAi** - プレイヤーのAIコード管理
- **GameMap** - マップデータとゴール位置管理

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

### AI実行方式

Smalruby甲子園では、Smalruby3フレームワークベースのAIコードを実行します：

**Smalruby3統合:**

- StageとSpriteオブジェクトの仮想実装
- koshienライブラリAPI完全サポート
- turn_overメカニズムによるターン制御
- listオブジェクトによるデータ管理

**セキュリティ機能:**

- サンドボックス化されたRubyコード実行
- 危険なメソッド（system, eval等）の除去
- タイムアウト保護（ターンあたり10秒）
- 例外処理とエラー分離

**Koshien APIメソッド:**

- `koshien.connect_game(name:)` - ゲーム接続
- `koshien.get_map_area(position)` - マップ探索
- `koshien.move_to(position)` - 指定位置への移動
- `koshien.calc_route(result:, src:, dst:, except_cells:)` - 経路計算
- `koshien.locate_objects(result:, cent:, sq_size:, objects:)` - オブジェクト探索
- `koshien.turn_over` - ターン終了
- `koshien.player` - 自分の位置取得
- `koshien.goal` - ゴール位置取得

**AIコードの例:**

```ruby
require "smalruby3"

Sprite.new(
  "スプライト1"
) do
  def self.減点アイテムを避けながらゴールにむかって1マス進む
    koshien.locate_objects(result: list("$通らない座標"), objects: "ABCD")
    koshien.calc_route(result: list("$最短経路"), src: koshien.player, dst: koshien.goal, except_cells: list("$通らない座標"))
    if list("$最短経路").length == 1
      # 減点アイテムで囲まれてしまっている場合は減点アイテムを避けずにゴールに向かう
      koshien.calc_route(result: list("$最短経路"))
    end
    koshien.move_to(list("$最短経路")[2])
  end

  koshien.connect_game(name: "player1")
  koshien.get_map_area("2:2")
  koshien.get_map_area("7:2")
  koshien.turn_over

  loop do
    koshien.get_map_area(koshien.player)
    減点アイテムを避けながらゴールにむかって1マス進む
    koshien.turn_over
  end
end
```

### ターン制御メカニズム

**turn_overシステム:**

- AIは複数のアクションを実行可能（探索、移動など）
- `koshien.turn_over`呼び出しでターン終了
- 1ターンに移動は1回まで（複数の探索は可能）
- 両プレイヤーがturn_overを呼ぶまで次ターンに進まない

**アクションタイプ:**

- `explore` - マップエリア探索アクション
- `move` - プレイヤー移動アクション（target_x, target_y指定）
- `wait` - 何もしない（デフォルト）

### エラーハンドリング

- **AiTimeoutError** - コード実行が制限時間を超過
- **AiSecurityError** - セキュリティポリシー違反
- **AiExecutionError** - 一般的な実行失敗（Stage/Spriteオブジェクト作成エラー等）

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

**敵（オロチ）システム:**

- 敵は状態（normal, angry, kill, done）を持つ
- 敵はkilledフラグで生存状態を管理（HPシステムは使用しない）
- 敵が攻撃可能な状態の時、プレイヤーは即座に完了状態になる
- スコアから減点（デフォルト-10ポイント）を適用
- 敵の撃退モード（enemy_kill）による特殊な相互作用

**敵の状態管理:**

- `normal_state`: 通常状態
- `angry`: 怒りモード（41ターン目以降）
- `kill`: やられるぞモード（草薙剣取得時）
- `done`: 撃退済み

**敵の撃退システム:**

- `no_kill`: どちらも撃退不可
- `player1_kill`: プレイヤー1のみ撃退可能
- `player2_kill`: プレイヤー2のみ撃退可能
- `both_kill`: 両プレイヤー撃退可能
- `kill_done`: 撃退済み

### スコアリングシステム

**スコア源:**

- アイテム収集: +10〜+60ポイント（プラスアイテム）
- アイテムペナルティ: -10〜-40ポイント（マイナスアイテム）
- 歩行ボーナス: 5回移動ごとに+3ポイント（walk_bonus_counter管理）
- ゴールボーナス: ゴール到達で+100ポイント
- 敵攻撃: 攻撃を受けると-10ポイント

**キャラクターレベリング:**

- レベルは総スコアから計算: `[(score - 1) / 20, 0].max.clamp(1, 8)`
- レベル1〜8の範囲で管理
- プレイヤーの見た目と能力に影響

**プレイヤー状態管理:**

- `playing`: プレイ中
- `completed`: ゴール到達または敵に倒された
- `timeout`: AIタイムアウト
- `timeup`: 制限時間切れ

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
- `EXPLORE` - マップエリア探索
- `WAIT` - プレイヤー待機

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

1. **AIタイムアウト** - コードの複雑さとループをチェック（解決済み：Stage/Spriteオブジェクト作成問題の修正）
2. **プライベートメソッドエラー** - MockKoshienからadd_actionメソッドアクセス問題（解決済み：メソッドを公開に変更）
3. **turn_over無限ループ** - turn_over呼び出しが無限に続く問題（解決済み：ターン終了ロジック修正）
4. **Stage.newオブジェクト作成エラー** - Smalruby3::Stageオブジェクトが返される問題（解決済み：文字列置換で対応）
5. **無効な移動** - マップ境界と障害物を確認
6. **イベント欠損** - TurnProcessorのイベントログを確認
7. **ジョブ失敗** - ジョブキューとエラーログを監視

### デバッグツール

```ruby
# デバッグログを有効化
Rails.logger.level = Logger::DEBUG

# デバッグスクリプトの使用
ruby script/debug_game_logic.rb

# 手動ゲーム実行
game_engine = GameEngine.new(game)
game_engine.execute_battle

# ゲーム状態確認
game.game_rounds.includes(:players, :enemies, game_turns: :game_events)

# AI実行ログの確認
tail -f log/development.log | grep -E "(AI execution|turn_over|koshien)"
```

## 最近の重要な修正事項

### AI実行タイムアウト問題の解決 (2025-09-22)

**問題:** プリセットAIが実行時にタイムアウトエラーが発生していた

**原因:**
1. Stage.new/Sprite.newオブジェクトが返されてeval結果となっていた
2. MockKoshienのadd_actionメソッドがprivateでアクセスできなかった
3. turn_over呼び出しが無限ループになっていた
4. exploreアクションタイプがTurnProcessorで未サポートだった

**解決策:**
1. AI前処理でStage.new→Stage、Sprite.new→Spriteに置換
2. add_actionメソッドをpublicに変更
3. turn_over呼び出し時に即座にターン終了するよう修正
4. TurnProcessorにexploreアクション処理を追加

### HP属性システムの削除 (2025-09-22)

**変更内容:**
- Enemy、PlayerモデルからHP属性を削除（vendor実装に合わせる）
- alive?、defeated?、take_damageメソッドを削除
- killed?メソッドをEnemyに追加（killed属性をチェック）
- encount_enemy?メソッドをPlayerに追加
- 敵攻撃時は即座にプレイヤーをcompleted状態に変更

### デバッグ機能の強化

**追加されたデバッグ機能:**
- script/debug_game_logic.rbスクリプト
- 詳細なAI実行ログ
- ゲーム状態分析機能
- プリセットAI/マップを使用したテスト環境

## 結論

Smalruby甲子園ゲームロジック実装は、AIプログラミング競技のための堅牢で安全、かつ拡張可能な基盤を提供します。このアーキテクチャは、セキュリティとパフォーマンスを維持しながら複雑なゲームメカニクスをサポートし、教育環境や競技プログラミングコンテストに適しています。

最近の修正により、プリセットAIの実行が安定し、vendor実装との互換性が確保されました。これにより、本格的なAI対戦が可能になっています。