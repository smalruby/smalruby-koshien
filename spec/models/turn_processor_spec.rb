require "rails_helper"

RSpec.describe TurnProcessor, type: :model do
  let!(:game_map) { create(:game_map) }
  let!(:first_player_ai) { create(:player_ai) }
  let!(:second_player_ai) { create(:player_ai) }
  let!(:game) { create(:game, game_map: game_map, first_player_ai: first_player_ai, second_player_ai: second_player_ai) }
  let!(:round) { game.game_rounds.create!(round_number: 1, status: :in_progress, item_locations: {}) }
  let!(:turn) { round.game_turns.create!(turn_number: 1, turn_finished: false) }
  let!(:player1) do
    round.players.create!(
      player_ai: first_player_ai,
      position_x: 1,
      position_y: 1,
      previous_position_x: 1,
      previous_position_y: 1,
      score: 0,
      character_level: 1,
      dynamite_left: 2,
      bomb_left: 2,
      walk_bonus_counter: 0,
      acquired_positive_items: [0, 0, 0, 0, 0, 0],
      status: :playing
    )
  end
  let!(:player2) do
    round.players.create!(
      player_ai: second_player_ai,
      position_x: 3,
      position_y: 3,
      previous_position_x: 3,
      previous_position_y: 3,
      score: 0,
      character_level: 1,
      dynamite_left: 2,
      bomb_left: 2,
      walk_bonus_counter: 0,
      acquired_positive_items: [0, 0, 0, 0, 0, 0],
      status: :playing
    )
  end
  let(:turn_processor) { described_class.new(round, turn) }
  let(:players) { [player1, player2] }

  describe "#process_actions" do
    let(:ai_results) do
      [
        {success: true, result: {action: {type: "move", direction: "up"}}},
        {success: true, result: {action: {type: "wait"}}}
      ]
    end

    it "プレイヤーのアクションを正常に処理する" do
      expect {
        turn_processor.process_actions(players, ai_results)
      }.to change(GameEvent, :count)

      player1.reload
      expect(player1.position_y).to eq(0) # 上に移動
    end

    it "AIが失敗した場合タイムアウトに設定する" do
      ai_results[0] = {success: false, error: "AI failed"}

      turn_processor.process_actions(players, ai_results)

      player1.reload
      expect(player1.status).to eq("timeout")
    end
  end

  describe "#process_movement" do
    context "有効な移動の場合" do
      it "プレイヤーを正しく移動させる" do
        turn_processor.send(:process_movement, player1, "right")

        player1.reload
        expect(player1.position_x).to eq(2)
        expect(player1.position_y).to eq(1)
        expect(player1.previous_position_x).to eq(1)
        expect(player1.previous_position_y).to eq(1)
      end

      it "移動イベントを作成する" do
        expect {
          turn_processor.send(:process_movement, player1, "right")
        }.to change(GameEvent, :count).by(1)

        event = GameEvent.last
        expect(event.event_type).to eq("MOVE")
        expect(event.event_data["direction"]).to eq("right")
      end
    end

    context "無効な移動の場合" do
      before do
        # マップの境界外に移動しようとする
        player1.update!(position_x: 0, position_y: 0)
      end

      it "プレイヤーを移動させない" do
        original_x = player1.position_x

        turn_processor.send(:process_movement, player1, "left")

        player1.reload
        expect(player1.position_x).to eq(original_x)
      end

      it "移動ブロックイベントを作成する" do
        expect {
          turn_processor.send(:process_movement, player1, "left")
        }.to change(GameEvent, :count).by(1)

        event = GameEvent.last
        expect(event.event_type).to eq("MOVE_BLOCKED")
      end
    end
  end

  describe "#process_item_usage" do
    context "ダイナマイト使用の場合" do
      it "ダイナマイトを正常に使用する" do
        expect {
          turn_processor.send(:process_item_usage, player1, "dynamite")
        }.to change { player1.reload.dynamite_left }.by(-1)

        expect(GameEvent.last.event_type).to eq("USE_DYNAMITE")
      end

      it "ダイナマイトがない場合失敗する" do
        player1.update!(dynamite_left: 0)

        turn_processor.send(:process_item_usage, player1, "dynamite")

        expect(GameEvent.last.event_type).to eq("USE_DYNAMITE_FAILED")
      end
    end

    context "爆弾使用の場合" do
      it "爆弾を正常に使用する" do
        expect {
          turn_processor.send(:process_item_usage, player1, "bomb")
        }.to change { player1.reload.bomb_left }.by(-1)

        expect(GameEvent.last.event_type).to eq("USE_BOMB")
      end

      it "爆弾がない場合失敗する" do
        player1.update!(bomb_left: 0)

        turn_processor.send(:process_item_usage, player1, "bomb")

        expect(GameEvent.last.event_type).to eq("USE_BOMB_FAILED")
      end
    end
  end

  describe "#process_collisions" do
    context "プレイヤー同士が衝突した場合" do
      before do
        # 両プレイヤーを同じ位置に配置
        player2.update!(position_x: player1.position_x, position_y: player1.position_y)
      end

      it "衝突イベントを作成する" do
        expect {
          turn_processor.send(:process_collisions)
        }.to change(GameEvent, :count).by(1)

        event = GameEvent.last
        expect(event.event_type).to eq("PLAYER_COLLISION")
        expect(event.event_data["player1_id"]).to eq(player1.id)
        expect(event.event_data["player2_id"]).to eq(player2.id)
      end
    end
  end

  describe "#process_item_interactions" do
    context "プレイヤーがアイテムの上にいる場合" do
      before do
        # アイテムをプレイヤーの位置に配置
        round.update!(item_locations: {
          "1" => {"1" => 2} # プレイヤー1の位置にアイテム2
        })
      end

      it "アイテムを収集する" do
        expect {
          turn_processor.send(:process_item_interactions)
        }.to change { player1.reload.score }

        expect(GameEvent.last.event_type).to eq("COLLECT_ITEM")
      end

      it "マップからアイテムを削除する" do
        turn_processor.send(:process_item_interactions)

        round.reload
        expect(round.item_locations["1"]["1"]).to eq(0) # アイテムブランクインデックス
      end
    end
  end

  describe "#process_enemy_interactions" do
    let!(:enemy) do
      round.enemies.create!(
        position_x: player1.position_x,
        position_y: player1.position_y,
        previous_position_x: player1.position_x,
        previous_position_y: player1.position_y,
        state: :normal_state,
        enemy_kill: :player1_kill
      )
    end

    it "敵がプレイヤーを攻撃する" do
      original_score = player1.score

      turn_processor.send(:process_enemy_interactions)

      player1.reload
      expect(player1.score).to eq(original_score + GameConstants::ENEMY_DISCOUNT)  # Score reduced by ENEMY_DISCOUNT
      expect(player1.status).to eq("playing")  # Player continues playing after enemy attack
      expect(GameEvent.last.event_type).to eq("ENEMY_ATTACK")
    end

    it "攻撃されたプレイヤーは1ラウンドにつき1回のみペナルティを受ける" do
      original_score = player1.score

      # First attack
      turn_processor.send(:process_enemy_interactions)
      player1.reload
      score_after_first = player1.score
      expect(score_after_first).to eq(original_score + GameConstants::ENEMY_DISCOUNT)

      # Second attack (should be ignored)
      turn_processor.send(:process_enemy_interactions)
      player1.reload
      expect(player1.score).to eq(score_after_first)  # Score unchanged on second attack
    end
  end

  describe "#update_player_scores" do
    context "プレイヤーが移動した場合" do
      before do
        player1.update!(
          position_x: 2,
          previous_position_x: 1,
          walk_bonus_counter: GameConstants::WALK_BONUS_BOUNDARY - 1
        )
      end

      it "歩行ボーナスを適用する" do
        original_score = player1.score

        turn_processor.send(:update_player_scores)

        player1.reload
        expect(player1.score).to be > original_score
        expect(player1.walk_bonus_counter).to eq(0)
      end

      it "歩行ボーナスイベントを作成する" do
        expect {
          turn_processor.send(:update_player_scores)
        }.to change(GameEvent, :count).by(1)

        expect(GameEvent.last.event_type).to eq("WALK_BONUS")
      end
    end
  end

  describe "#calculate_new_position" do
    it "上移動の新しい位置を計算する" do
      new_x, new_y = turn_processor.send(:calculate_new_position, 5, 5, "up")
      expect([new_x, new_y]).to eq([5, 4])
    end

    it "下移動の新しい位置を計算する" do
      new_x, new_y = turn_processor.send(:calculate_new_position, 5, 5, "down")
      expect([new_x, new_y]).to eq([5, 6])
    end

    it "左移動の新しい位置を計算する" do
      new_x, new_y = turn_processor.send(:calculate_new_position, 5, 5, "left")
      expect([new_x, new_y]).to eq([4, 5])
    end

    it "右移動の新しい位置を計算する" do
      new_x, new_y = turn_processor.send(:calculate_new_position, 5, 5, "right")
      expect([new_x, new_y]).to eq([6, 5])
    end
  end

  describe "#valid_movement?" do
    context "マップ内の有効な位置の場合" do
      it "移動を許可する" do
        expect(turn_processor.send(:valid_movement?, 0, 0)).to be true
      end
    end

    context "マップ境界外の場合" do
      it "移動を拒否する" do
        expect(turn_processor.send(:valid_movement?, -1, -1)).to be false
        expect(turn_processor.send(:valid_movement?, 1000, 1000)).to be false
      end
    end
  end
end
