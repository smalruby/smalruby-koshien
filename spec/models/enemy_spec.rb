require "rails_helper"

RSpec.describe Enemy, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {}) }
  let(:enemy) { Enemy.new(game_round: game_round, position_x: 5, position_y: 5, hp: 100, attack_power: 20) }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(enemy).to be_valid
    end

    it "game_roundが必須である" do
      enemy.game_round = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:game_round]).to include("must exist")
    end

    it "position_xが必須である" do
      enemy.position_x = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_x]).to include("can't be blank")
    end

    it "position_xが非負数である" do
      enemy.position_x = -1
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_x]).to include("must be greater than or equal to 0")
    end

    it "position_yが必須である" do
      enemy.position_y = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_y]).to include("can't be blank")
    end

    it "position_yが非負数である" do
      enemy.position_y = -1
      expect(enemy).not_to be_valid
      expect(enemy.errors[:position_y]).to include("must be greater than or equal to 0")
    end

    it "hpが必須である" do
      enemy.hp = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:hp]).to include("can't be blank")
    end

    it "hpが非負数である" do
      enemy.hp = -1
      expect(enemy).not_to be_valid
      expect(enemy.errors[:hp]).to include("must be greater than or equal to 0")
    end

    it "attack_powerが必須である" do
      enemy.attack_power = nil
      expect(enemy).not_to be_valid
      expect(enemy.errors[:attack_power]).to include("can't be blank")
    end

    it "attack_powerが非負数である" do
      enemy.attack_power = -1
      expect(enemy).not_to be_valid
      expect(enemy.errors[:attack_power]).to include("must be greater than or equal to 0")
    end
  end

  describe "#position" do
    it "xとyのハッシュを返す" do
      expected_position = {x: 5, y: 5}
      expect(enemy.position).to eq(expected_position)
    end
  end

  describe "#alive?" do
    it "hpが0より大きい時にtrueを返す" do
      enemy.hp = 50
      expect(enemy).to be_alive
    end

    it "hpが0の時にfalseを返す" do
      enemy.hp = 0
      expect(enemy).not_to be_alive
    end

    it "hpが負数の時にfalseを返す" do
      enemy.hp = -10
      expect(enemy).not_to be_alive
    end
  end

  describe "#defeated?" do
    it "hpが0より大きい時にfalseを返す" do
      enemy.hp = 50
      expect(enemy).not_to be_defeated
    end

    it "hpが0の時にtrueを返す" do
      enemy.hp = 0
      expect(enemy).to be_defeated
    end

    it "hpが負数の時にtrueを返す" do
      enemy.hp = -10
      expect(enemy).to be_defeated
    end
  end

  describe "alive?とdefeated?の関係" do
    it "hp > 0の時は反対の結果である" do
      enemy.hp = 50
      expect(enemy.alive?).to eq(!enemy.defeated?)
    end

    it "hp = 0の時は反対の結果である" do
      enemy.hp = 0
      expect(enemy.alive?).to eq(!enemy.defeated?)
    end
  end
end
