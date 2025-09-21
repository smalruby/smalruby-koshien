require "rails_helper"

RSpec.describe PlayerAi, type: :model do
  let(:player_ai) { PlayerAi.new(name: "Test AI", code: "test code", author: "test author") }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(player_ai).to be_valid
    end

    it "nameが必須である" do
      player_ai.name = nil
      expect(player_ai).not_to be_valid
      expect(player_ai.errors[:name]).to include("can't be blank")
    end

    it "nameが一意である" do
      PlayerAi.create!(name: "Test AI", code: "test code")
      expect(player_ai).not_to be_valid
      expect(player_ai.errors[:name]).to include("has already been taken")
    end

    it "nameの長さを検証する" do
      player_ai.name = "a" * 101
      expect(player_ai).not_to be_valid
      expect(player_ai.errors[:name]).to include("is too long (maximum is 100 characters)")
    end

    it "codeが必須である" do
      player_ai.code = nil
      expect(player_ai).not_to be_valid
      expect(player_ai.errors[:code]).to include("can't be blank")
    end

    it "codeの長さを検証する" do
      player_ai.code = "a" * 10001
      expect(player_ai).not_to be_valid
      expect(player_ai.errors[:code]).to include("is too long (maximum is 10000 characters)")
    end

    it "authorの長さを検証する" do
      player_ai.author = "a" * 101
      expect(player_ai).not_to be_valid
      expect(player_ai.errors[:author]).to include("is too long (maximum is 100 characters)")
    end
  end

  describe "関連" do
    before { player_ai.save! }

    it "複数のfirst_player_gameを持つ" do
      game_map = GameMap.create!(name: "Test Map", map_data: [[0, 0, 0]], goal_position: {"x" => 1, "y" => 1})
      other_ai = PlayerAi.create!(name: "Other AI", code: "test")
      game = Game.create!(first_player_ai: player_ai, second_player_ai: other_ai, game_map: game_map, battle_url: "https://test.com")

      expect(player_ai.first_player_games).to include(game)
    end

    it "複数のsecond_player_gameを持つ" do
      game_map = GameMap.create!(name: "Test Map", map_data: [[0, 0, 0]], goal_position: {"x" => 1, "y" => 1})
      other_ai = PlayerAi.create!(name: "Other AI", code: "test")
      game = Game.create!(first_player_ai: other_ai, second_player_ai: player_ai, game_map: game_map, battle_url: "https://test.com")

      expect(player_ai.second_player_games).to include(game)
    end
  end

  describe "スコープ" do
    let!(:available_ai) { PlayerAi.create!(name: "Available AI", code: "test") }
    let!(:expired_ai) { PlayerAi.create!(name: "Expired AI", code: "test") }
    let!(:preset_ai) { PlayerAi.create!(name: "Preset AI", code: "test", author: "system") }

    before do
      # Manually set expires_at after creation to override callback
      available_ai.update_column(:expires_at, 1.day.from_now)
      expired_ai.update_column(:expires_at, 1.day.ago)
    end

    describe ".available" do
      it "期限切れでないAIを返す" do
        expect(PlayerAi.available).to include(available_ai)
        expect(PlayerAi.available).not_to include(expired_ai)
      end
    end

    describe ".expired" do
      it "期限切れのAIを返す" do
        expect(PlayerAi.expired).to include(expired_ai)
        expect(PlayerAi.expired).not_to include(available_ai)
      end
    end

    describe ".preset" do
      it "システムAIを返す" do
        expect(PlayerAi.preset).to include(preset_ai)
        expect(PlayerAi.preset).not_to include(available_ai)
      end
    end
  end

  describe "#expired?" do
    it "expires_atが過去の時にtrueを返す" do
      player_ai.expires_at = 1.day.ago
      expect(player_ai).to be_expired
    end

    it "expires_atが未来の時にfalseを返す" do
      player_ai.expires_at = 1.day.from_now
      expect(player_ai).not_to be_expired
    end
  end

  describe "#preset?" do
    it "authorがsystemの時にtrueを返す" do
      player_ai.author = "system"
      expect(player_ai).to be_preset
    end

    it "authorがsystemでない時にfalseを返す" do
      player_ai.author = "user"
      expect(player_ai).not_to be_preset
    end
  end

  describe "コールバック" do
    describe "before_create :set_expiration" do
      it "プリセットAIの期限を1年に設定する" do
        preset_ai = PlayerAi.new(name: "Preset", code: "test", author: "system")
        preset_ai.save!

        expect(preset_ai.expires_at).to be_within(1.minute).of(1.year.from_now)
      end

      it "通常のAIの期限を2日に設定する" do
        regular_ai = PlayerAi.new(name: "Regular", code: "test", author: "user")
        regular_ai.save!

        expect(regular_ai.expires_at).to be_within(1.minute).of(2.days.from_now)
      end
    end
  end
end
