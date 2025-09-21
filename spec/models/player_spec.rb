require "rails_helper"

RSpec.describe Player, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {}) }
  let(:player) { Player.new(game_round: game_round, player_ai: player_ai_1, position_x: 3, position_y: 4, score: 50, dynamite_left: 2, character_level: 1) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(player).to be_valid
    end

    it "requires game_round" do
      player.game_round = nil
      expect(player).not_to be_valid
      expect(player.errors[:game_round]).to include("must exist")
    end

    it "requires player_ai" do
      player.player_ai = nil
      expect(player).not_to be_valid
      expect(player.errors[:player_ai]).to include("must exist")
    end

    it "requires position_x" do
      player.position_x = nil
      expect(player).not_to be_valid
      expect(player.errors[:position_x]).to include("can't be blank")
    end

    it "requires non-negative position_x" do
      player.position_x = -1
      expect(player).not_to be_valid
      expect(player.errors[:position_x]).to include("must be greater than or equal to 0")
    end

    it "requires position_y" do
      player.position_y = nil
      expect(player).not_to be_valid
      expect(player.errors[:position_y]).to include("can't be blank")
    end

    it "requires non-negative position_y" do
      player.position_y = -1
      expect(player).not_to be_valid
      expect(player.errors[:position_y]).to include("must be greater than or equal to 0")
    end

    it "requires score" do
      player.score = nil
      expect(player).not_to be_valid
      expect(player.errors[:score]).to include("can't be blank")
    end

    it "requires non-negative score" do
      player.score = -1
      expect(player).not_to be_valid
      expect(player.errors[:score]).to include("must be greater than or equal to 0")
    end

    it "requires dynamite_left" do
      player.dynamite_left = nil
      expect(player).not_to be_valid
      expect(player.errors[:dynamite_left]).to include("can't be blank")
    end

    it "requires non-negative dynamite_left" do
      player.dynamite_left = -1
      expect(player).not_to be_valid
      expect(player.errors[:dynamite_left]).to include("must be greater than or equal to 0")
    end

    it "requires character_level" do
      player.character_level = nil
      expect(player).not_to be_valid
      expect(player.errors[:character_level]).to include("can't be blank")
    end

    it "requires character_level to be at least 1" do
      player.character_level = 0
      expect(player).not_to be_valid
      expect(player.errors[:character_level]).to include("must be greater than or equal to 1")
    end
  end

  describe "enums" do
    describe "status enum" do
      it "works correctly" do
        player.status = :active
        expect(player).to be_active

        player.status = :inactive
        expect(player).to be_inactive

        player.status = :defeated
        expect(player).to be_defeated
      end
    end
  end

  describe "position methods" do
    describe "#position" do
      it "returns array with x and y" do
        expected_position = [3, 4]
        expect(player.position).to eq(expected_position)
      end
    end

    describe "#previous_position" do
      it "returns array with previous x and y" do
        player.previous_position_x = 1
        player.previous_position_y = 2
        expected_position = [1, 2]
        expect(player.previous_position).to eq(expected_position)
      end
    end

    describe "#move_to" do
      it "updates position and stores previous position" do
        player.move_to(5, 6)

        expect(player.position_x).to eq(5)
        expect(player.position_y).to eq(6)
        expect(player.previous_position_x).to eq(3)
        expect(player.previous_position_y).to eq(4)
      end
    end

    describe "#has_moved?" do
      it "returns true when position changed" do
        player.move_to(5, 6)
        expect(player).to have_moved
      end

      it "returns false when position has not changed" do
        player.previous_position_x = player.position_x
        player.previous_position_y = player.position_y
        expect(player).not_to have_moved
      end
    end
  end

  describe "dynamite methods" do
    describe "#can_use_dynamite?" do
      it "returns true when dynamite_left > 0" do
        player.dynamite_left = 2
        expect(player.can_use_dynamite?).to be true
      end

      it "returns false when dynamite_left is 0" do
        player.dynamite_left = 0
        expect(player.can_use_dynamite?).to be false
      end
    end

    describe "#use_dynamite" do
      it "decreases dynamite_left and returns true when available" do
        player.dynamite_left = 2
        result = player.use_dynamite

        expect(result).to be true
        expect(player.dynamite_left).to eq(1)
      end

      it "returns false when no dynamite left" do
        player.dynamite_left = 0
        result = player.use_dynamite

        expect(result).to be false
        expect(player.dynamite_left).to eq(0)
      end
    end
  end

  describe "bonus methods" do
    describe "#apply_goal_bonus" do
      it "adds 100 to score and sets has_goal_bonus" do
        player.has_goal_bonus = false
        player.score = 50
        result = player.apply_goal_bonus

        expect(result).to be true
        expect(player.score).to eq(150)
        expect(player.has_goal_bonus?).to be true
      end

      it "returns false if already has goal bonus" do
        player.has_goal_bonus = true
        player.score = 50
        result = player.apply_goal_bonus

        expect(result).to be false
        expect(player.score).to eq(50)
      end
    end

    describe "#apply_walk_bonus" do
      it "adds 1 to score and sets walk_bonus when moved" do
        player.walk_bonus = false
        player.score = 50
        player.move_to(5, 6)
        result = player.apply_walk_bonus

        expect(result).to be true
        expect(player.score).to eq(51)
        expect(player.walk_bonus?).to be true
      end

      it "returns false if already has walk bonus" do
        player.walk_bonus = true
        player.score = 50
        player.move_to(5, 6)
        result = player.apply_walk_bonus

        expect(result).to be false
        expect(player.score).to eq(50)
      end

      it "returns false if has not moved" do
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

  describe "scopes" do
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
      it "returns only active players" do
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

      it "filters by position" do
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
