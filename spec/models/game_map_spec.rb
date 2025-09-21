require "rails_helper"

RSpec.describe GameMap, type: :model do
  let(:game_map) { GameMap.new(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(game_map).to be_valid
    end

    it "nameが必須である" do
      game_map.name = nil
      expect(game_map).not_to be_valid
      expect(game_map.errors[:name]).to include("can't be blank")
    end

    it "nameが一意である" do
      GameMap.create!(name: "Test Map", map_data: [[0]], goal_position: {"x" => 1, "y" => 1})
      expect(game_map).not_to be_valid
      expect(game_map.errors[:name]).to include("has already been taken")
    end

    it "nameの長さを検証する" do
      game_map.name = "a" * 101
      expect(game_map).not_to be_valid
      expect(game_map.errors[:name]).to include("is too long (maximum is 100 characters)")
    end

    it "map_dataが必須である" do
      game_map.map_data = nil
      expect(game_map).not_to be_valid
      expect(game_map.errors[:map_data]).to include("can't be blank")
    end

    it "goal_positionが必須である" do
      game_map.goal_position = nil
      expect(game_map).not_to be_valid
      expect(game_map.errors[:goal_position]).to include("can't be blank")
    end

    describe "map_dataフォーマット検証" do
      it "map_dataが2次元配列であることを検証する" do
        game_map.map_data = "invalid"
        expect(game_map).not_to be_valid
        expect(game_map.errors[:map_data]).to include("must be a 2D array")
      end

      it "すべての行が配列であることを検証する" do
        game_map.map_data = [0, 1, 2]
        expect(game_map).not_to be_valid
        expect(game_map.errors[:map_data]).to include("must be a 2D array")
      end
    end

    describe "goal_positionフォーマット検証" do
      it "goal_positionがxとyキーを持つハッシュであることを検証する" do
        game_map.goal_position = "invalid"
        expect(game_map).not_to be_valid
        expect(game_map.errors[:goal_position]).to include("must be a hash with x and y keys")
      end

      it "goal_positionがxキーを持つことを検証する" do
        game_map.goal_position = {"y" => 1}
        expect(game_map).not_to be_valid
        expect(game_map.errors[:goal_position]).to include("must be a hash with x and y keys")
      end

      it "goal_positionがyキーを持つことを検証する" do
        game_map.goal_position = {"x" => 1}
        expect(game_map).not_to be_valid
        expect(game_map.errors[:goal_position]).to include("must be a hash with x and y keys")
      end
    end
  end

  describe "関連" do
    before { game_map.save! }

    it "複数のgameを持つ" do
      player_ai_1 = PlayerAi.create!(name: "AI 1", code: "test")
      player_ai_2 = PlayerAi.create!(name: "AI 2", code: "test")
      game = Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com")

      expect(game_map.games).to include(game)
    end

    it "gameが存在する時は削除を制限する" do
      player_ai_1 = PlayerAi.create!(name: "AI 1", code: "test")
      player_ai_2 = PlayerAi.create!(name: "AI 2", code: "test")
      Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com")

      expect(game_map.destroy).to be false
      expect(game_map.errors.messages).to be_present
    end
  end

  describe "シリアライゼーション" do
    before { game_map.save! }

    it "map_dataをJSONとしてシリアライズする" do
      game_map.reload
      expect(game_map.map_data).to eq([[0, 0, 0], [0, 1, 0], [0, 0, 0]])
    end

    it "goal_positionをJSONとしてシリアライズする" do
      game_map.reload
      expect(game_map.goal_position).to eq({"x" => 2, "y" => 2})
    end
  end

  describe "#size" do
    it "正しい幅と高さを返す" do
      expect(game_map.size).to eq({width: 3, height: 3})
    end

    it "空のmap_dataを処理する" do
      game_map.map_data = []
      expect(game_map.size).to eq({width: 0, height: 0})
    end
  end

  describe "#goal_position_object" do
    it "シンボル化されたキーを返す" do
      goal = game_map.goal_position_object
      expect(goal).to eq({x: 2, y: 2})
    end

    it "ハッシュでないgoal_positionを処理する" do
      game_map.goal_position = "invalid"
      expect(game_map.goal_position_object).to be_nil
    end
  end

  describe ".preset_maps" do
    let!(:preset_map1) { GameMap.create!(name: "map1", map_data: [[0]], goal_position: {"x" => 1, "y" => 1}) }
    let!(:preset_map2) { GameMap.create!(name: "map5", map_data: [[0]], goal_position: {"x" => 1, "y" => 1}) }
    let!(:custom_map) { GameMap.create!(name: "custom", map_data: [[0]], goal_position: {"x" => 1, "y" => 1}) }

    it "プリセットマップのみを返す" do
      preset_maps = GameMap.preset_maps
      expect(preset_maps).to include(preset_map1, preset_map2)
      expect(preset_maps).not_to include(custom_map)
    end
  end
end
