require "rails_helper"

RSpec.describe GameRound, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.new(game: game, round_number: 1, status: :preparing, item_locations: {"1,1" => "coin", "5,5" => "gem"}) }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(game_round).to be_valid
    end

    it "gameが必須である" do
      game_round.game = nil
      expect(game_round).not_to be_valid
      expect(game_round.errors[:game]).to include("must exist")
    end

    it "round_numberが必須である" do
      game_round.round_number = nil
      expect(game_round).not_to be_valid
      expect(game_round.errors[:round_number]).to include("can't be blank")
    end

    it "statusが必須である" do
      game_round.status = nil
      expect(game_round).not_to be_valid
      expect(game_round.errors[:status]).to include("can't be blank")
    end

    it "item_locationsが必須である" do
      game_round.item_locations = nil
      expect(game_round).not_to be_valid
      expect(game_round.errors[:item_locations]).to include("can't be blank")
    end

    it "gameごとのround_numberの一意性を検証する" do
      game_round.save!

      duplicate_round = GameRound.new(
        game: game,
        round_number: 1,
        status: :preparing,
        item_locations: {}
      )

      expect(duplicate_round).not_to be_valid
      expect(duplicate_round.errors[:round_number]).to include("has already been taken")
    end

    it "異なるgameで同じround_numberを許可する" do
      game_round.save!

      another_game = Game.create!(
        first_player_ai: player_ai_1,
        second_player_ai: player_ai_2,
        game_map: game_map,
        battle_url: "https://test.example.com/battle/2"
      )

      another_round = GameRound.new(
        game: another_game,
        round_number: 1,
        status: :preparing,
        item_locations: {}
      )

      expect(another_round).to be_valid
    end
  end

  describe "関連" do
    before { game_round.save! }

    it "複数のplayerをdependent destroyで持つ" do
      player = Player.create!(
        game_round: game_round,
        player_ai: player_ai_1,
        position_x: 0,
        position_y: 0,
        score: 0,
        dynamite_left: 3,
        character_level: 1
      )

      expect(game_round.players).to include(player)
      expect { game_round.destroy }.to change(Player, :count).by(-1)
    end

    it "複数のenemyをdependent destroyで持つ" do
      enemy = Enemy.create!(
        game_round: game_round,
        position_x: 5,
        position_y: 5,
        hp: 100,
        attack_power: 20
      )

      expect(game_round.enemies).to include(enemy)
      expect { game_round.destroy }.to change(Enemy, :count).by(-1)
    end

    it "複数のgame_turnをdependent destroyで持つ" do
      game_turn = GameTurn.create!(
        game_round: game_round,
        turn_number: 1,
        turn_finished: false
      )

      expect(game_round.game_turns).to include(game_turn)
      expect { game_round.destroy }.to change(GameTurn, :count).by(-1)
    end
  end

  describe "enum" do
    describe "status enum" do
      it "正常に動作する" do
        game_round.status = :preparing
        expect(game_round).to be_preparing

        game_round.status = :in_progress
        expect(game_round).to be_in_progress

        game_round.status = :finished
        expect(game_round).to be_finished
      end
    end

    describe "winner enum" do
      it "正常に動作する" do
        game_round.winner = :no_winner
        expect(game_round).to be_no_winner

        game_round.winner = :player1
        expect(game_round).to be_player1

        game_round.winner = :player2
        expect(game_round).to be_player2

        game_round.winner = :draw
        expect(game_round).to be_draw
      end
    end
  end

  describe "スコープ" do
    before { game_round.save! }

    let!(:round_2) { GameRound.create!(game: game, round_number: 2, status: :preparing, item_locations: {}) }

    describe ".by_round_number" do
      it "ラウンド番号でフィルタリングする" do
        round_1_results = GameRound.by_round_number(1)
        round_2_results = GameRound.by_round_number(2)

        expect(round_1_results).to include(game_round)
        expect(round_1_results).not_to include(round_2)
        expect(round_2_results).to include(round_2)
        expect(round_2_results).not_to include(game_round)
      end
    end

    describe ".finished_rounds" do
      it "終了したラウンドのみを返す" do
        finished_round = GameRound.create!(
          game: game,
          round_number: 3,
          status: :finished,
          item_locations: {}
        )

        finished_rounds = GameRound.finished_rounds

        expect(finished_rounds).to include(finished_round)
        expect(finished_rounds).not_to include(game_round)
      end
    end
  end
end
