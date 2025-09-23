require "rails_helper"

RSpec.describe Enemy, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {}) }
  let(:enemy) { Enemy.new(game_round: game_round, position_x: 5, position_y: 5) }

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
  end

  describe "#position" do
    it "xとyのハッシュを返す" do
      expected_position = {x: 5, y: 5}
      expect(enemy.position).to eq(expected_position)
    end
  end

  describe "#killed?" do
    it "初期状態ではfalseを返す" do
      expect(enemy.killed?).to be_falsey
    end

    it "killedがtrueの時にtrueを返す" do
      enemy.killed = true
      expect(enemy.killed?).to be_truthy
    end

    it "killedがfalseの時にfalseを返す" do
      enemy.killed = false
      expect(enemy.killed?).to be_falsey
    end
  end

  describe "ステート管理" do
    it "normal?メソッドでnormal_stateを判定できる" do
      enemy.state = :normal_state
      expect(enemy.normal?).to be_truthy
    end

    it "angry?メソッドでangryステートを判定できる" do
      enemy.state = :angry
      expect(enemy.angry?).to be_truthy
    end

    it "kill?メソッドでkillステートを判定できる" do
      enemy.state = :kill
      expect(enemy.kill?).to be_truthy
    end
  end

  describe "#can_attack?" do
    it "both_killの場合にプレイヤー0に対してtrueを返す" do
      enemy.enemy_kill = :both_kill
      expect(enemy.can_attack?(0)).to be_truthy
    end

    it "both_killの場合にプレイヤー1に対してtrueを返す" do
      enemy.enemy_kill = :both_kill
      expect(enemy.can_attack?(1)).to be_truthy
    end

    it "player1_killの場合にプレイヤー0に対してtrueを返す" do
      enemy.enemy_kill = :player1_kill
      expect(enemy.can_attack?(0)).to be_truthy
    end

    it "player1_killの場合にプレイヤー1に対してfalseを返す" do
      enemy.enemy_kill = :player1_kill
      expect(enemy.can_attack?(1)).to be_falsey
    end

    it "player2_killの場合にプレイヤー0に対してfalseを返す" do
      enemy.enemy_kill = :player2_kill
      expect(enemy.can_attack?(0)).to be_falsey
    end

    it "player2_killの場合にプレイヤー1に対してtrueを返す" do
      enemy.enemy_kill = :player2_kill
      expect(enemy.can_attack?(1)).to be_truthy
    end

    it "no_killの場合に両プレイヤーに対してfalseを返す" do
      enemy.enemy_kill = :no_kill
      expect(enemy.can_attack?(0)).to be_falsey
      expect(enemy.can_attack?(1)).to be_falsey
    end
  end
end
