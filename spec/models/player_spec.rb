require "rails_helper"

RSpec.describe Player, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {}) }
  let(:player) { Player.new(game_round: game_round, player_ai: player_ai_1, position_x: 3, position_y: 4, score: 50, dynamite_left: 2, character_level: 1) }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(player).to be_valid
    end

    it "game_roundが必須である" do
      player.game_round = nil
      expect(player).not_to be_valid
      expect(player.errors[:game_round]).to include("must exist")
    end

    it "player_aiが必須である" do
      player.player_ai = nil
      expect(player).not_to be_valid
      expect(player.errors[:player_ai]).to include("must exist")
    end

    it "position_xが必須である" do
      player.position_x = nil
      expect(player).not_to be_valid
      expect(player.errors[:position_x]).to include("can't be blank")
    end

    it "position_xが非負数である" do
      player.position_x = -1
      expect(player).not_to be_valid
      expect(player.errors[:position_x]).to include("must be greater than or equal to 0")
    end

    it "position_yが必須である" do
      player.position_y = nil
      expect(player).not_to be_valid
      expect(player.errors[:position_y]).to include("can't be blank")
    end

    it "position_yが非負数である" do
      player.position_y = -1
      expect(player).not_to be_valid
      expect(player.errors[:position_y]).to include("must be greater than or equal to 0")
    end

    it "scoreが必須である" do
      player.score = nil
      expect(player).not_to be_valid
      expect(player.errors[:score]).to include("can't be blank")
    end

    it "scoreが非負数である" do
      player.score = -1
      expect(player).not_to be_valid
      expect(player.errors[:score]).to include("must be greater than or equal to 0")
    end

    it "dynamite_leftが必須である" do
      player.dynamite_left = nil
      expect(player).not_to be_valid
      expect(player.errors[:dynamite_left]).to include("can't be blank")
    end

    it "dynamite_leftが非負数である" do
      player.dynamite_left = -1
      expect(player).not_to be_valid
      expect(player.errors[:dynamite_left]).to include("must be greater than or equal to 0")
    end

    it "character_levelが必須である" do
      player.character_level = nil
      expect(player).not_to be_valid
      expect(player.errors[:character_level]).to include("can't be blank")
    end

    it "character_levelが1以上である" do
      player.character_level = 0
      expect(player).not_to be_valid
      expect(player.errors[:character_level]).to include("must be greater than or equal to 1")
    end
  end

  describe "enum" do
    describe "status enum" do
      it "正常に動作する" do
        player.status = :active
        expect(player).to be_active

        player.status = :inactive
        expect(player).to be_inactive

        player.status = :defeated
        expect(player).to be_defeated
      end
    end
  end

  describe "位置メソッド" do
    describe "#position" do
      it "xとyの配列を返す" do
        expected_position = [3, 4]
        expect(player.position).to eq(expected_position)
      end
    end

    describe "#previous_position" do
      it "前のxとyの配列を返す" do
        player.previous_position_x = 1
        player.previous_position_y = 2
        expected_position = [1, 2]
        expect(player.previous_position).to eq(expected_position)
      end
    end

    describe "#move_to" do
      it "位置を更新し前の位置を保存する" do
        player.move_to(5, 6)

        expect(player.position_x).to eq(5)
        expect(player.position_y).to eq(6)
        expect(player.previous_position_x).to eq(3)
        expect(player.previous_position_y).to eq(4)
      end
    end

    describe "#has_moved?" do
      it "位置が変更された時にtrueを返す" do
        player.move_to(5, 6)
        expect(player).to have_moved
      end

      it "位置が変更されていない時にfalseを返す" do
        player.previous_position_x = player.position_x
        player.previous_position_y = player.position_y
        expect(player).not_to have_moved
      end
    end
  end

  describe "ダイナマイトメソッド" do
    describe "#can_use_dynamite?" do
      it "dynamite_leftが0より大きい時にtrueを返す" do
        player.dynamite_left = 2
        expect(player.can_use_dynamite?).to be true
      end

      it "dynamite_leftが0の時にfalseを返す" do
        player.dynamite_left = 0
        expect(player.can_use_dynamite?).to be false
      end
    end

    describe "#use_dynamite" do
      it "利用可能な時にdynamite_leftを減らしtrueを返す" do
        player.dynamite_left = 2
        result = player.use_dynamite

        expect(result).to be true
        expect(player.dynamite_left).to eq(1)
      end

      it "ダイナマイトが残っていない時にfalseを返す" do
        player.dynamite_left = 0
        result = player.use_dynamite

        expect(result).to be false
        expect(player.dynamite_left).to eq(0)
      end
    end
  end

  describe "ボーナスメソッド" do
    describe "#apply_goal_bonus" do
      it "スコアに100を加算しhas_goal_bonusを設定する" do
        player.has_goal_bonus = false
        player.score = 50
        result = player.apply_goal_bonus

        expect(result).to be true
        expect(player.score).to eq(150)
        expect(player.has_goal_bonus?).to be true
      end

      it "既にゴールボーナスを持っている場合はfalseを返す" do
        player.has_goal_bonus = true
        player.score = 50
        result = player.apply_goal_bonus

        expect(result).to be false
        expect(player.score).to eq(50)
      end
    end

    describe "#apply_walk_bonus" do
      it "移動時にスコアに1を加算しwalk_bonusを設定する" do
        player.walk_bonus = false
        player.score = 50
        player.move_to(5, 6)
        result = player.apply_walk_bonus

        expect(result).to be true
        expect(player.score).to eq(51)
        expect(player.walk_bonus?).to be true
      end

      it "既に歩行ボーナスを持っている場合はfalseを返す" do
        player.walk_bonus = true
        player.score = 50
        player.move_to(5, 6)
        result = player.apply_walk_bonus

        expect(result).to be false
        expect(player.score).to eq(50)
      end

      it "移動していない場合はfalseを返す" do
        player.walk_bonus = false
        player.score = 50
        # Set previous position to current position to simulate no movement
        player.previous_position_x = player.position_x
        player.previous_position_y = player.position_y
        result = player.apply_walk_bonus

        expect(result).to be false
        expect(player.score).to eq(50)
        expect(player.walk_bonus?).to be false
      end
    end
  end

  describe "スコープ" do
    before do
      player.status = :active
      player.save!
    end

    let!(:inactive_player) do
      Player.create!(
        game_round: game_round,
        player_ai: player_ai_2,
        position_x: 0,
        position_y: 0,
        score: 0,
        dynamite_left: 3,
        character_level: 1,
        status: :inactive
      )
    end

    describe ".active_players" do
      it "アクティブなプレイヤーのみを返す" do
        active_players = Player.active_players

        expect(active_players).to include(player)
        expect(active_players).not_to include(inactive_player)
      end
    end

    describe ".by_position" do
      let!(:different_position_player) do
        Player.create!(
          game_round: game_round,
          player_ai: player_ai_2,
          position_x: 5,
          position_y: 5,
          score: 0,
          dynamite_left: 3,
          character_level: 1
        )
      end

      it "位置でフィルタリングする" do
        players_at_3_4 = Player.by_position(3, 4)
        players_at_5_5 = Player.by_position(5, 5)

        expect(players_at_3_4).to include(player)
        expect(players_at_3_4).not_to include(different_position_player)
        expect(players_at_5_5).to include(different_position_player)
        expect(players_at_5_5).not_to include(player)
      end
    end
  end
end
