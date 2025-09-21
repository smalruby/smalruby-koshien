require "rails_helper"

RSpec.describe Game, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.new(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(game).to be_valid
    end

    it "first_player_aiが必須である" do
      game.first_player_ai = nil
      expect(game).not_to be_valid
      expect(game.errors[:first_player_ai]).to include("must exist")
    end

    it "second_player_aiが必須である" do
      game.second_player_ai = nil
      expect(game).not_to be_valid
      expect(game.errors[:second_player_ai]).to include("must exist")
    end

    it "game_mapが必須である" do
      game.game_map = nil
      expect(game).not_to be_valid
      expect(game.errors[:game_map]).to include("must exist")
    end

    it "作成時にbattle_urlが必須である" do
      new_game = Game.new(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map)
      expect(new_game).not_to be_valid
      expect(new_game.errors[:battle_url]).to include("can't be blank")
    end
  end

  describe "関連" do
    before { game.save! }

    it "first_player_aiに属する" do
      expect(game.first_player_ai).to eq(player_ai_1)
    end

    it "second_player_aiに属する" do
      expect(game.second_player_ai).to eq(player_ai_2)
    end

    it "game_mapに属する" do
      expect(game.game_map).to eq(game_map)
    end

    it "複数のgame_roundを持つ" do
      game_round = GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {})
      expect(game.game_rounds).to include(game_round)
    end

    it "削除時に関連するgame_roundを削除する" do
      GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {})
      expect { game.destroy }.to change(GameRound, :count).by(-1)
    end
  end

  describe "enum" do
    describe "status enum" do
      it "正常に動作する" do
        game.status = :waiting_for_players
        expect(game).to be_waiting_for_players

        game.status = :in_progress
        expect(game).to be_in_progress

        game.status = :completed
        expect(game).to be_completed

        game.status = :cancelled
        expect(game).to be_cancelled
      end
    end

    describe "winner enum" do
      it "正常に動作する" do
        game.winner = :first
        expect(game).to be_winner_first

        game.winner = :second
        expect(game).to be_winner_second
      end
    end
  end

  describe "スコープ" do
    let!(:old_game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com/old") }
    let!(:cancelled_game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com/cancelled", status: :cancelled) }

    before do
      old_game.update_column(:created_at, 1.day.ago)
      game.save!
    end

    describe ".recent" do
      it "created_atの降順で並べ替える" do
        recent_games = Game.recent
        expect(recent_games.first).to eq(game)
        expect(recent_games.last).to eq(old_game)
      end
    end

    describe ".active" do
      it "waiting_for_playersとin_progressのgameを返す" do
        game.update!(status: :waiting_for_players)
        active_games = Game.active
        expect(active_games).to include(game)
        expect(active_games).not_to include(cancelled_game)
      end
    end
  end

  describe "インスタンスメソッド" do
    describe "#finished?" do
      it "完了時にtrueを返す" do
        game.status = :completed
        expect(game).to be_finished
      end

      it "キャンセル時にtrueを返す" do
        game.status = :cancelled
        expect(game).to be_finished
      end

      it "進行中にfalseを返す" do
        game.status = :in_progress
        expect(game).not_to be_finished
      end
    end

    describe "#player_ais" do
      it "両方のplayer AIの配列を返す" do
        expect(game.player_ais).to eq([player_ai_1, player_ai_2])
      end
    end

    describe "#winner_ai" do
      it "勝者がfirstの時にfirst_player_aiを返す" do
        game.status = :completed
        game.winner = :first
        expect(game.winner_ai).to eq(player_ai_1)
      end

      it "勝者がsecondの時にsecond_player_aiを返す" do
        game.status = :completed
        game.winner = :second
        expect(game.winner_ai).to eq(player_ai_2)
      end

      it "ゲームが終了していない時にnilを返す" do
        game.status = :in_progress
        expect(game.winner_ai).to be_nil
      end

      it "勝者が設定されていない時にnilを返す" do
        game.status = :completed
        game.winner = nil
        expect(game.winner_ai).to be_nil
      end
    end

    describe "#loser_ai" do
      it "勝者がfirstの時にsecond_player_aiを返す" do
        game.status = :completed
        game.winner = :first
        expect(game.loser_ai).to eq(player_ai_2)
      end

      it "勝者がsecondの時にfirst_player_aiを返す" do
        game.status = :completed
        game.winner = :second
        expect(game.loser_ai).to eq(player_ai_1)
      end

      it "ゲームが終了していない時にnilを返す" do
        game.status = :in_progress
        expect(game.loser_ai).to be_nil
      end
    end

    describe "#generate_battle_url" do
      it "ゲームIDでバトルURLを生成する" do
        game.save!
        game.generate_battle_url
        expect(game.battle_url).to eq("https://koshien.smalruby.app/battles/#{game.id}")
      end
    end
  end
end
