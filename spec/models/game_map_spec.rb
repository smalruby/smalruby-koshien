require "rails_helper"

RSpec.describe GameMap, type: :model do
  let(:game_map) { GameMap.new(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(game_map).to be_valid
    end

    it "requires name" do
      game_map.name = nil
      expect(game_map).not_to be_valid
      expect(game_map.errors[:name]).to include("can't be blank")
    end

    it "requires name to be unique" do
      GameMap.create!(name: "Test Map", map_data: [[0]], goal_position: {"x" => 1, "y" => 1})
      expect(game_map).not_to be_valid
      expect(game_map.errors[:name]).to include("has already been taken")
    end

    it "validates name length" do
      game_map.name = "a" * 101
      expect(game_map).not_to be_valid
      expect(game_map.errors[:name]).to include("is too long (maximum is 100 characters)")
    end

    it "requires map_data" do
      game_map.map_data = nil
      expect(game_map).not_to be_valid
      expect(game_map.errors[:map_data]).to include("can't be blank")
    end

    it "requires goal_position" do
      game_map.goal_position = nil
      expect(game_map).not_to be_valid
      expect(game_map.errors[:goal_position]).to include("can't be blank")
    end

    describe "map_data format validation" do
      it "validates map_data is a 2D array" do
        game_map.map_data = "invalid"
        expect(game_map).not_to be_valid
        expect(game_map.errors[:map_data]).to include("must be a 2D array")
      end

      it "validates all rows are arrays" do
        game_map.map_data = [0, 1, 2]
        expect(game_map).not_to be_valid
        expect(game_map.errors[:map_data]).to include("must be a 2D array")
      end
    end

    describe "goal_position format validation" do
      it "validates goal_position is a hash with x and y keys" do
        game_map.goal_position = "invalid"
        expect(game_map).not_to be_valid
        expect(game_map.errors[:goal_position]).to include("must be a hash with x and y keys")
      end

      it "validates goal_position has x key" do
        game_map.goal_position = {"y" => 1}
        expect(game_map).not_to be_valid
        expect(game_map.errors[:goal_position]).to include("must be a hash with x and y keys")
      end

      it "validates goal_position has y key" do
        game_map.goal_position = {"x" => 1}
        expect(game_map).not_to be_valid
        expect(game_map.errors[:goal_position]).to include("must be a hash with x and y keys")
      end
    end
  end

  describe "associations" do
    before { game_map.save! }

    it "has many games" do
      player_ai_1 = PlayerAi.create!(name: "AI 1", code: "test")
      player_ai_2 = PlayerAi.create!(name: "AI 2", code: "test")
      game = Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com")

      expect(game_map.games).to include(game)
    end

    it "restricts deletion when games exist" do
      player_ai_1 = PlayerAi.create!(name: "AI 1", code: "test")
      player_ai_2 = PlayerAi.create!(name: "AI 2", code: "test")
      Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com")

      expect(game_map.destroy).to be false
      expect(game_map.errors.messages).to be_present
    end
  end

  describe "serialization" do
    before { game_map.save! }

    it "serializes map_data as JSON" do
      game_map.reload
      expect(game_map.map_data).to eq([[0, 0, 0], [0, 1, 0], [0, 0, 0]])
    end

    it "serializes goal_position as JSON" do
      game_map.reload
      expect(game_map.goal_position).to eq({"x" => 2, "y" => 2})
    end
  end

  describe "#size" do
    it "returns correct width and height" do
      expect(game_map.size).to eq({width: 3, height: 3})
    end

    it "handles empty map_data" do
      game_map.map_data = []
      expect(game_map.size).to eq({width: 0, height: 0})
    end
  end

  describe "#goal_position_object" do
    it "returns symbolized keys" do
      goal = game_map.goal_position_object
      expect(goal).to eq({x: 2, y: 2})
    end

    it "handles non-hash goal_position" do
      game_map.goal_position = "invalid"
      expect(game_map.goal_position_object).to be_nil
    end
  end

  describe ".preset_maps" do
    let!(:preset_map1) { GameMap.create!(name: "map1", map_data: [[0]], goal_position: {"x" => 1, "y" => 1}) }
    let!(:preset_map2) { GameMap.create!(name: "map5", map_data: [[0]], goal_position: {"x" => 1, "y" => 1}) }
    let!(:custom_map) { GameMap.create!(name: "custom", map_data: [[0]], goal_position: {"x" => 1, "y" => 1}) }

    it "returns only preset maps" do
      preset_maps = GameMap.preset_maps
      expect(preset_maps).to include(preset_map1, preset_map2)
      expect(preset_maps).not_to include(custom_map)
    end
  end
end
