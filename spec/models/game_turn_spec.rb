require "rails_helper"

RSpec.describe GameTurn, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {}) }
  let(:game_turn) { GameTurn.new(game_round: game_round, turn_number: 1, turn_finished: false) }

  describe "バリデーション" do
    it "有効な属性で有効である" do
      expect(game_turn).to be_valid
    end

    it "game_roundが必須である" do
      game_turn.game_round = nil
      expect(game_turn).not_to be_valid
      expect(game_turn.errors[:game_round]).to include("must exist")
    end

    it "turn_numberが必須である" do
      game_turn.turn_number = nil
      expect(game_turn).not_to be_valid
      expect(game_turn.errors[:turn_number]).to include("can't be blank")
    end

    it "turn_numberが正数である" do
      game_turn.turn_number = 0
      expect(game_turn).not_to be_valid
      expect(game_turn.errors[:turn_number]).to include("must be greater than 0")
    end

    it "turn_finishedがブール値である" do
      game_turn.turn_finished = nil
      expect(game_turn).not_to be_valid
      expect(game_turn.errors[:turn_finished]).to include("is not included in the list")
    end
  end

  describe "関連" do
    before { game_turn.save! }

    it "複数のgame_eventを持つ" do
      game_event = GameEvent.create!(
        game_turn: game_turn,
        event_type: GameEvent::PLAYER_MOVE,
        event_data: {player_id: 1, from: [0, 0], to: [1, 0]}
      )
      expect(game_turn.game_events).to include(game_event)
    end

    it "削除時に関連するgame_eventを削除する" do
      GameEvent.create!(
        game_turn: game_turn,
        event_type: GameEvent::PLAYER_MOVE,
        event_data: {player_id: 1, from: [0, 0], to: [1, 0]}
      )

      expect { game_turn.destroy }.to change(GameEvent, :count).by(-1)
    end
  end

  describe "スコープ" do
    let!(:finished_turn) { GameTurn.create!(game_round: game_round, turn_number: 10, turn_finished: true) }
    let!(:unfinished_turn) { GameTurn.create!(game_round: game_round, turn_number: 11, turn_finished: false) }

    describe ".finished" do
      it "終了したターンを返す" do
        expect(GameTurn.finished).to include(finished_turn)
        expect(GameTurn.finished).not_to include(unfinished_turn)
      end
    end

    describe ".unfinished" do
      it "未終了のターンを返す" do
        expect(GameTurn.unfinished).to include(unfinished_turn)
        expect(GameTurn.unfinished).not_to include(finished_turn)
      end
    end

    describe ".ordered" do
      it "turn_numberで並べたターンを返す" do
        GameTurn.create!(game_round: game_round, turn_number: 20, turn_finished: false)
        GameTurn.create!(game_round: game_round, turn_number: 21, turn_finished: false)
        GameTurn.create!(game_round: game_round, turn_number: 22, turn_finished: false)

        ordered_turns = GameTurn.where(turn_number: [20, 21, 22]).ordered
        expect(ordered_turns.pluck(:turn_number)).to eq([20, 21, 22])
      end
    end
  end
end
