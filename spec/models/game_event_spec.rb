require "rails_helper"

RSpec.describe GameEvent, type: :model do
  let(:game_map) { GameMap.create!(name: "Test Map", map_data: [[0, 0, 0], [0, 1, 0], [0, 0, 0]], goal_position: {"x" => 2, "y" => 2}) }
  let(:player_ai_1) { PlayerAi.create!(name: "Test AI 1", code: "test code", author: "test") }
  let(:player_ai_2) { PlayerAi.create!(name: "Test AI 2", code: "test code", author: "test") }
  let(:game) { Game.create!(first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map, battle_url: "https://test.example.com/battle/1") }
  let(:game_round) { GameRound.create!(game: game, round_number: 1, status: :preparing, item_locations: {}) }
  let(:game_turn) { GameTurn.create!(game_round: game_round, turn_number: 1, turn_finished: false) }
  let(:game_event) { GameEvent.new(game_turn: game_turn, event_type: GameEvent::PLAYER_MOVE, event_data: {player_id: 1, from: [0, 0], to: [1, 0]}) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(game_event).to be_valid
    end

    it "requires game_turn" do
      game_event.game_turn = nil
      expect(game_event).not_to be_valid
      expect(game_event.errors[:game_turn]).to include("must exist")
    end

    it "requires event_type" do
      game_event.event_type = nil
      expect(game_event).not_to be_valid
      expect(game_event.errors[:event_type]).to include("can't be blank")
    end

    it "requires event_data" do
      game_event.event_data = nil
      expect(game_event).not_to be_valid
      expect(game_event.errors[:event_data]).to include("can't be blank")
    end

    it "validates event_type inclusion" do
      game_event.event_type = "invalid_type"
      expect(game_event).not_to be_valid
      expect(game_event.errors[:event_type]).to include("is not included in the list")
    end

    it "accepts valid event types" do
      GameEvent::EVENT_TYPES.each do |event_type|
        game_event.event_type = event_type
        expect(game_event).to be_valid, "#{event_type} should be valid"
      end
    end
  end

  describe "event_data serialization" do
    it "serializes event_data as JSON" do
      game_event.save!
      game_event.reload
      expect(game_event.event_data).to eq({"player_id" => 1, "from" => [0, 0], "to" => [1, 0]})
    end
  end

  describe "scopes" do
    before do
      game_event.save!
    end

    describe ".by_type" do
      it "filters by event type" do
        item_event = GameEvent.create!(game_turn: game_turn, event_type: GameEvent::ITEM_COLLECT, event_data: {player_id: 1, item_type: "coin"})

        move_events = GameEvent.by_type(GameEvent::PLAYER_MOVE)
        item_events = GameEvent.by_type(GameEvent::ITEM_COLLECT)

        expect(move_events).to include(game_event)
        expect(move_events).not_to include(item_event)
        expect(item_events).to include(item_event)
        expect(item_events).not_to include(game_event)
      end
    end

    describe ".ordered" do
      it "orders by turn number and created_at" do
        sleep(0.001) # Ensure different created_at times

        later_turn = GameTurn.create!(game_round: game_round, turn_number: 2, turn_finished: false)

        event_1_later = GameEvent.create!(
          game_turn: game_turn,
          event_type: GameEvent::ENEMY_ENCOUNTER,
          event_data: {player_id: 1, enemy_id: 1}
        )

        event_2 = GameEvent.create!(
          game_turn: later_turn,
          event_type: GameEvent::ITEM_COLLECT,
          event_data: {player_id: 2, item_type: "gem"}
        )

        ordered_events = GameEvent.ordered
        expect(ordered_events.to_a).to eq([game_event, event_1_later, event_2])
      end
    end
  end

  describe "constants" do
    it "defines event type constants" do
      expect(GameEvent::PLAYER_MOVE).to eq("player_move")
      expect(GameEvent::ITEM_COLLECT).to eq("item_collect")
      expect(GameEvent::ENEMY_ENCOUNTER).to eq("enemy_encounter")
      expect(GameEvent::GAME_END).to eq("game_end")
    end

    it "includes all defined constants in EVENT_TYPES" do
      expected_types = [
        GameEvent::PLAYER_MOVE,
        GameEvent::ITEM_COLLECT,
        GameEvent::ENEMY_ENCOUNTER,
        GameEvent::GAME_END
      ]
      expect(GameEvent::EVENT_TYPES).to eq(expected_types)
    end
  end
end
