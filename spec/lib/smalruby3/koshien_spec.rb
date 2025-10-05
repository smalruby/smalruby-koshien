# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::Koshien do
  let(:koshien) { described_class.instance }

  # Set up a minimal game state for testing
  before do
    # Create test game data
    game_map = GameMap.create!(
      name: "Test Map",
      description: "Test map for Koshien spec",
      map_data: Array.new(15) { Array.new(15) { 0 } }, # All space cells (15x15)
      map_height: Array.new(15) { Array.new(15) { 0 } },
      goal_position: {"x" => 14, "y" => 14}
    )

    player_ai = PlayerAi.create!(
      name: "test_ai",
      code: "# test code"
    )

    game = Game.create!(
      first_player_ai: player_ai,
      second_player_ai: player_ai,
      game_map: game_map,
      battle_url: "test_koshien_spec",
      status: :in_progress
    )

    game_round = GameRound.create!(
      game: game,
      round_number: 1,
      item_locations: {}
    )

    player = Player.create!(
      game_round: game_round,
      player_ai: player_ai,
      position_x: 0,
      position_y: 0,
      score: 0,
      dynamite_left: 3,
      bomb_left: 2,
      walk_bonus_counter: 0,
      acquired_positive_items: [nil, 0, 0, 0, 0, 0],
      in_water: false,
      character_level: 1,
      status: :playing,
      has_goal_bonus: false,
      walk_bonus: false
    )

    GameTurn.create!(
      game_round: game_round,
      turn_number: 1,
      turn_finished: false
    )

    # Create visible map data (explored cells)
    visible_map = {}
    15.times do |x|
      15.times do |y|
        visible_map["#{x}_#{y}"] = 0 # All explored as space
      end
    end

    # Set up koshien instance with test data
    koshien.instance_variable_set(:@game, game)
    koshien.instance_variable_set(:@player, player)
    koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
    koshien.instance_variable_set(:@current_turn_data, {
      "player_x" => 0,
      "player_y" => 0,
      "goal_x" => 14,
      "goal_y" => 14,
      "visible_map" => visible_map
    })
  end

  describe "#calc_route" do
    it "calculates route from current position to goal" do
      result = Smalruby3::List.new
      koshien.calc_route(result: result)

      expect(result.length).to be > 0
      expect(result[1]).to eq("0:0") # Start position
      expect(result[result.length]).to eq("14:14") # Goal position
    end

    it "calculates route with custom src and dst" do
      result = Smalruby3::List.new
      koshien.calc_route(result: result, src: "2:2", dst: "5:5")

      expect(result.length).to be > 0
      expect(result[1]).to eq("2:2")
      expect(result[result.length]).to eq("5:5")
    end

    it "handles except_cells parameter to avoid specific cells" do
      result = Smalruby3::List.new
      # Create a route that would normally go through 1:0, but exclude it
      koshien.calc_route(result: result, src: "0:0", dst: "2:0", except_cells: ["1:0"])

      # The route should not contain the excluded cell
      expect(result.to_s).not_to include("1:0")
    end

    it "returns route as position strings in List format" do
      result = Smalruby3::List.new
      koshien.calc_route(result: result, src: "0:0", dst: "3:0")

      # Check that all elements are position strings (x:y format)
      result.each do |pos|
        expect(pos).to match(/\A\d+:\d+\z/)
      end
    end

    it "updates the provided result list" do
      result = Smalruby3::List.new
      return_value = koshien.calc_route(result: result, src: "0:0", dst: "2:2")

      # Should return the same list object
      expect(return_value).to be(result)
      expect(result.length).to be > 0
    end
  end

  describe "#map" do
    it "returns map data for explored position" do
      value = koshien.map("0:0")
      expect(value).to eq(0) # Space cell
    end

    it "returns -1 for unexplored position when no visible_map" do
      koshien.instance_variable_set(:@current_turn_data, nil)
      value = koshien.map("0:0")
      expect(value).to eq(-1)
    end
  end

  describe "#map_all" do
    it "returns map string representation" do
      result = koshien.map_all
      expect(result).to be_a(String)

      # Should be 15 rows separated by commas
      rows = result.split(",")
      expect(rows.length).to eq(15)
      expect(rows.first.length).to eq(15)
    end

    it "returns empty map when no turn data" do
      koshien.instance_variable_set(:@current_turn_data, nil)
      result = koshien.map_all
      expect(result).to be_a(String)
    end
  end

  describe "#map_from" do
    it "returns map data from map_all string" do
      map_string = koshien.map_all
      value = koshien.map_from("0:0", map_string)
      expect(value).to eq(0)
    end
  end
end
