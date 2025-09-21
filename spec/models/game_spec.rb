require "rails_helper"

RSpec.describe Game, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.new(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(game).to be_valid
    end

    it "requires first_player_ai" do
      game.first_player_ai = nil
      expect(game).not_to be_valid
      expect(game.errors[:first_player_ai]).to include("must exist")
    end

    it "requires second_player_ai" do
      game.second_player_ai = nil
      expect(game).not_to be_valid
      expect(game.errors[:second_player_ai]).to include("must exist")
    end

    it "requires game_map" do
      game.game_map = nil
      expect(game).not_to be_valid
      expect(game.errors[:game_map]).to include("must exist")
    end

    it "requires battle_url on create" do
      new_game = Game.new(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map)
      expect(new_game).not_to be_valid
      expect(new_game.errors[:battle_url]).to include("can't be blank")
    end
  end

  describe "associations" do
    before { game.save! }

    it "belongs to first_player_ai" do
      expect(game.first_player_ai).to eq(player_ai_1)
    end

    it "belongs to second_player_ai" do
      expect(game.second_player_ai).to eq(player_ai_2)
    end

    it "belongs to game_map" do
      expect(game.game_map).to eq(game_map)
    end

    it "has many game_rounds" do
      game_round = GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {})
      expect(game.game_rounds).to include(game_round)
    end

    it "destroys associated game_rounds when destroyed" do
      GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {})
      expect { game.destroy }.to change(GameRound, :count).by(-1)
    end
  end

  describe "enums" do
    describe "status enum" do
      it "works correctly" do
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
      it "works correctly" do
        game.winner = :first
        expect(game).to be_winner_first

        game.winner = :second
        expect(game).to be_winner_second
      end
    end
  end

  describe "scopes" do
    let!(:old_game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com/old") }
    let!(:cancelled_game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.com/cancelled", status: :cancelled) }

    before do
      old_game.update_column(:created_at, 1.day.ago)
      game.save!
    end

    describe ".recent" do
      it "orders by created_at descending" do
        recent_games = Game.recent
        expect(recent_games.first).to eq(game)
        expect(recent_games.last).to eq(old_game)
      end
    end

    describe ".active" do
      it "returns waiting_for_players and in_progress games" do
        game.update!(status: :waiting_for_players)
        active_games = Game.active
        expect(active_games).to include(game)
        expect(active_games).not_to include(cancelled_game)
      end
    end
  end

  describe "instance methods" do
    describe "#finished?" do
      it "returns true when completed" do
        game.status = :completed
        expect(game).to be_finished
      end

      it "returns true when cancelled" do
        game.status = :cancelled
        expect(game).to be_finished
      end

      it "returns false when in progress" do
        game.status = :in_progress
        expect(game).not_to be_finished
      end
    end

    describe "#player_ais" do
      it "returns array of both player AIs" do
        expect(game.player_ais).to eq([player_ai_1, player_ai_2])
      end
    end

    describe "#winner_ai" do
      it "returns first_player_ai when winner is first" do
        game.status = :completed
        game.winner = :first
        expect(game.winner_ai).to eq(player_ai_1)
      end

      it "returns second_player_ai when winner is second" do
        game.status = :completed
        game.winner = :second
        expect(game.winner_ai).to eq(player_ai_2)
      end

      it "returns nil when game is not finished" do
        game.status = :in_progress
        expect(game.winner_ai).to be_nil
      end

      it "returns nil when winner is not set" do
        game.status = :completed
        game.winner = nil
        expect(game.winner_ai).to be_nil
      end
    end

    describe "#loser_ai" do
      it "returns second_player_ai when winner is first" do
        game.status = :completed
        game.winner = :first
        expect(game.loser_ai).to eq(player_ai_2)
      end

      it "returns first_player_ai when winner is second" do
        game.status = :completed
        game.winner = :second
        expect(game.loser_ai).to eq(player_ai_1)
      end

      it "returns nil when game is not finished" do
        game.status = :in_progress
        expect(game.loser_ai).to be_nil
      end
    end

    describe "#generate_battle_url" do
      it "generates battle URL with game ID" do
        game.save!
        game.generate_battle_url
        expect(game.battle_url).to eq("https://koshien.smalruby.app/battles/#{game.id}")
      end
    end
  end
end
