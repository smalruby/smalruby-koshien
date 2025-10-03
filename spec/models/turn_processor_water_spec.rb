require "rails_helper"

RSpec.describe TurnProcessor, type: :model do
  let(:game_map) { create(:game_map, map_data: [
    [0, 0, 0, 0, 0],
    [0, 0, 4, 0, 0],  # Water at (2,1)
    [0, 0, 0, 0, 3]   # Goal at (4,2)
  ]) }
  let(:player_ai_1) { create(:player_ai) }
  let(:player_ai_2) { create(:player_ai) }
  let(:game) { create(:game, first_player_ai: player_ai_1, second_player_ai: player_ai_2, game_map: game_map) }
  let(:game_round) { create(:game_round, game: game) }
  let(:game_turn) { create(:game_turn, game_round: game_round, turn_number: 1) }
  let(:player1) { create(:player, game_round: game_round, position_x: 1, position_y: 1) }
  let(:turn_processor) { described_class.new(game_round, game_turn) }

  describe "water movement" do
    it "allows player to move into water" do
      ai_results = [{success: true, result: {action: {action_type: "move", target_x: 2, target_y: 1}}}]

      turn_processor.process_actions([player1], ai_results)
      player1.reload

      expect(player1.position_x).to eq(2)
      expect(player1.position_y).to eq(1)
    end

    it "creates ENTER_WATER event when player enters water" do
      ai_results = [{success: true, result: {action: {action_type: "move", target_x: 2, target_y: 1}}}]

      turn_processor.process_actions([player1], ai_results)

      water_events = GameEvent.where(event_type: "ENTER_WATER")
      expect(water_events.count).to eq(1)
      expect(water_events.first.event_data["position"]).to eq({"x" => 2, "y" => 1})
    end

    it "does not create ENTER_WATER event when player moves to non-water cell" do
      ai_results = [{success: true, result: {action: {action_type: "move", target_x: 1, target_y: 0}}}]

      turn_processor.process_actions([player1], ai_results)

      water_events = GameEvent.where(event_type: "ENTER_WATER")
      expect(water_events.count).to eq(0)
    end
  end
end
