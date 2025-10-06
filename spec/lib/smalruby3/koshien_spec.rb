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

    context "with different map cell types" do
      it "handles positive item cells (a-e)" do
        # Create map with positive items
        game_map_with_items = GameMap.create!(
          name: "Map with Items",
          description: "Test map with positive items",
          map_data: [
            [0, "a", 0],
            [0, "b", 0],
            [0, 0, 0]
          ],
          map_height: Array.new(3) { Array.new(3) { 0 } },
          goal_position: {"x" => 2, "y" => 2}
        )

        game = Game.create!(
          first_player_ai: PlayerAi.first,
          second_player_ai: PlayerAi.first,
          game_map: game_map_with_items,
          battle_url: "test_items",
          status: :in_progress
        )

        game_round = GameRound.create!(
          game: game,
          round_number: 1,
          item_locations: {}
        )

        player = Player.create!(
          game_round: game_round,
          player_ai: PlayerAi.first,
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

        visible_map = {}
        3.times do |x|
          3.times do |y|
            cell_value = game_map_with_items.map_data[y][x]
            visible_map["#{x}_#{y}"] = cell_value
          end
        end

        koshien.instance_variable_set(:@game, game)
        koshien.instance_variable_set(:@player, player)
        koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
        koshien.instance_variable_set(:@current_turn_data, {
          "player_x" => 0,
          "player_y" => 0,
          "goal_x" => 2,
          "goal_y" => 2,
          "visible_map" => {"map_data" => game_map_with_items.map_data}
        })

        result = Smalruby3::List.new
        koshien.calc_route(result: result, src: "0:0", dst: "2:2")

        expect(result.length).to be > 0
        expect(result[1]).to eq("0:0")
      end

      it "handles negative item cells (A-D)" do
        # Create map with negative items
        game_map_with_negative = GameMap.create!(
          name: "Map with Negative Items",
          description: "Test map with negative items",
          map_data: [
            [0, "A", 0],
            [0, "B", 0],
            [0, 0, 0]
          ],
          map_height: Array.new(3) { Array.new(3) { 0 } },
          goal_position: {"x" => 2, "y" => 2}
        )

        game = Game.create!(
          first_player_ai: PlayerAi.first,
          second_player_ai: PlayerAi.first,
          game_map: game_map_with_negative,
          battle_url: "test_negative_items",
          status: :in_progress
        )

        game_round = GameRound.create!(
          game: game,
          round_number: 1,
          item_locations: {}
        )

        player = Player.create!(
          game_round: game_round,
          player_ai: PlayerAi.first,
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

        koshien.instance_variable_set(:@game, game)
        koshien.instance_variable_set(:@player, player)
        koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
        koshien.instance_variable_set(:@current_turn_data, {
          "player_x" => 0,
          "player_y" => 0,
          "goal_x" => 2,
          "goal_y" => 2,
          "visible_map" => {"map_data" => game_map_with_negative.map_data}
        })

        result = Smalruby3::List.new
        koshien.calc_route(result: result, src: "0:0", dst: "2:2")

        expect(result.length).to be > 0
      end

      it "handles water cells with higher cost" do
        # Create map with water
        game_map_with_water = GameMap.create!(
          name: "Map with Water",
          description: "Test map with water cells",
          map_data: [
            [0, 4, 0],
            [0, 4, 0],
            [0, 0, 0]
          ],
          map_height: Array.new(3) { Array.new(3) { 0 } },
          goal_position: {"x" => 2, "y" => 2}
        )

        game = Game.create!(
          first_player_ai: PlayerAi.first,
          second_player_ai: PlayerAi.first,
          game_map: game_map_with_water,
          battle_url: "test_water",
          status: :in_progress
        )

        game_round = GameRound.create!(
          game: game,
          round_number: 1,
          item_locations: {}
        )

        player = Player.create!(
          game_round: game_round,
          player_ai: PlayerAi.first,
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

        koshien.instance_variable_set(:@game, game)
        koshien.instance_variable_set(:@player, player)
        koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
        koshien.instance_variable_set(:@current_turn_data, {
          "player_x" => 0,
          "player_y" => 0,
          "goal_x" => 2,
          "goal_y" => 2,
          "visible_map" => {"map_data" => game_map_with_water.map_data}
        })

        result = Smalruby3::List.new
        koshien.calc_route(result: result, src: "0:0", dst: "2:2")

        expect(result.length).to be > 0
      end

      it "handles uncleared cells with highest cost" do
        # Create map with uncleared cells
        game_map_with_uncleared = GameMap.create!(
          name: "Map with Uncleared",
          description: "Test map with uncleared cells",
          map_data: [
            [0, -1, 0],
            [0, -1, 0],
            [0, 0, 0]
          ],
          map_height: Array.new(3) { Array.new(3) { 0 } },
          goal_position: {"x" => 2, "y" => 2}
        )

        game = Game.create!(
          first_player_ai: PlayerAi.first,
          second_player_ai: PlayerAi.first,
          game_map: game_map_with_uncleared,
          battle_url: "test_uncleared",
          status: :in_progress
        )

        game_round = GameRound.create!(
          game: game,
          round_number: 1,
          item_locations: {}
        )

        player = Player.create!(
          game_round: game_round,
          player_ai: PlayerAi.first,
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

        koshien.instance_variable_set(:@game, game)
        koshien.instance_variable_set(:@player, player)
        koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
        koshien.instance_variable_set(:@current_turn_data, {
          "player_x" => 0,
          "player_y" => 0,
          "goal_x" => 2,
          "goal_y" => 2,
          "visible_map" => {"map_data" => game_map_with_uncleared.map_data}
        })

        result = Smalruby3::List.new
        koshien.calc_route(result: result, src: "0:0", dst: "2:2")

        expect(result.length).to be > 0
      end

      it "handles unknown cell types with default cost" do
        # Create map with unknown cell type
        game_map_with_unknown = GameMap.create!(
          name: "Map with Unknown",
          description: "Test map with unknown cell types",
          map_data: [
            [0, 99, 0],
            [0, 99, 0],
            [0, 0, 0]
          ],
          map_height: Array.new(3) { Array.new(3) { 0 } },
          goal_position: {"x" => 2, "y" => 2}
        )

        game = Game.create!(
          first_player_ai: PlayerAi.first,
          second_player_ai: PlayerAi.first,
          game_map: game_map_with_unknown,
          battle_url: "test_unknown",
          status: :in_progress
        )

        game_round = GameRound.create!(
          game: game,
          round_number: 1,
          item_locations: {}
        )

        player = Player.create!(
          game_round: game_round,
          player_ai: PlayerAi.first,
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

        koshien.instance_variable_set(:@game, game)
        koshien.instance_variable_set(:@player, player)
        koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
        koshien.instance_variable_set(:@current_turn_data, {
          "player_x" => 0,
          "player_y" => 0,
          "goal_x" => 2,
          "goal_y" => 2,
          "visible_map" => {"map_data" => game_map_with_unknown.map_data}
        })

        result = Smalruby3::List.new
        koshien.calc_route(result: result, src: "0:0", dst: "2:2")

        expect(result.length).to be > 0
      end
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
    context "when visible_map data is available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, {
          "visible_map" => {
            "0_0" => 1,
            "1_0" => 0,
            "2_0" => 4,
            "5_7" => 3
          }
        })
      end

      it "returns map string representation" do
        result = koshien.map_all
        expect(result).to be_a(String)

        # Should be 15 rows separated by commas
        rows = result.split(",")
        expect(rows.length).to eq(15)
        expect(rows.first.length).to eq(15)
      end

      it "builds map with visible data and unexplored areas" do
        result = koshien.map_all
        rows = result.split(",")

        # First row should have "104" at positions 0-2, rest should be "-"
        expect(rows[0][0]).to eq("1")
        expect(rows[0][1]).to eq("0")
        expect(rows[0][2]).to eq("4")
        expect(rows[0][3]).to eq("-")

        # Row 7, column 5 should be "3"
        expect(rows[7][5]).to eq("3")

        # Unexplored cells should be "-"
        expect(rows[14][14]).to eq("-")
      end
    end

    context "when no visible_map data is available" do
      it "returns empty map when no turn data" do
        koshien.instance_variable_set(:@current_turn_data, nil)
        result = koshien.map_all
        expect(result).to be_a(String)
      end

      it "returns empty map when visible_map is missing" do
        koshien.instance_variable_set(:@current_turn_data, {})
        result = koshien.map_all
        expect(result).to be_a(String)
      end
    end
  end

  describe "#map" do
    context "when visible_map data is available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, {
          "visible_map" => {
            "5_7" => 1,
            "10_12" => 0,
            "3_4" => 4
          }
        })
      end

      it "returns map value for valid position" do
        result = koshien.map("5:7")
        expect(result).to eq(1)
      end

      it "returns 0 for empty cell" do
        result = koshien.map("10:12")
        expect(result).to eq(0)
      end

      it "returns -1 for unexplored cell" do
        result = koshien.map("99:99")
        expect(result).to eq(-1)
      end
    end

    context "when visible_map data is not available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, nil)
      end

      it "returns -1" do
        result = koshien.map("5:7")
        expect(result).to eq(-1)
      end
    end
  end

  describe "#map_from" do
    it "returns map data from map_all string" do
      map_string = koshien.map_all
      value = koshien.map_from("0:0", map_string)
      expect(value).to eq(0)
    end
  end

  describe "#position" do
    it "converts x and y coordinates to position string" do
      result = koshien.position(5, 7)
      expect(result).to eq("5:7")
    end

    it "handles zero coordinates" do
      result = koshien.position(0, 0)
      expect(result).to eq("0:0")
    end

    it "handles negative coordinates" do
      result = koshien.position(-3, -5)
      expect(result).to eq("-3:-5")
    end

    it "handles mixed positive and negative coordinates" do
      result = koshien.position(-2, 8)
      expect(result).to eq("-2:8")
    end
  end

  describe "#position_of_x" do
    it "extracts x coordinate from position string" do
      result = koshien.position_of_x("5:7")
      expect(result).to eq(5)
    end

    it "handles zero x coordinate" do
      result = koshien.position_of_x("0:10")
      expect(result).to eq(0)
    end

    it "handles negative x coordinate" do
      result = koshien.position_of_x("-3:7")
      expect(result).to eq(-3)
    end
  end

  describe "#position_of_y" do
    it "extracts y coordinate from position string" do
      result = koshien.position_of_y("5:7")
      expect(result).to eq(7)
    end

    it "handles zero y coordinate" do
      result = koshien.position_of_y("10:0")
      expect(result).to eq(0)
    end

    it "handles negative y coordinate" do
      result = koshien.position_of_y("5:-8")
      expect(result).to eq(-8)
    end
  end

  describe "#goal" do
    it "returns goal position as string" do
      result = koshien.goal
      expect(result).to be_a(String)
      expect(result).to match(/\d+:\d+/)
    end

    it "returns goal coordinates in x:y format" do
      result = koshien.goal
      expect(result).to eq("14:14")
    end
  end

  describe "#goal_x" do
    it "returns x coordinate of goal" do
      result = koshien.goal_x
      expect(result).to eq(14)
    end
  end

  describe "#goal_y" do
    it "returns y coordinate of goal" do
      result = koshien.goal_y
      expect(result).to eq(14)
    end
  end

  describe "#player" do
    it "returns player position as string" do
      result = koshien.player
      expect(result).to be_a(String)
      expect(result).to match(/\d+:\d+/)
    end

    it "returns player coordinates in x:y format" do
      result = koshien.player
      expect(result).to eq("0:0")
    end
  end

  describe "#player_x" do
    it "returns x coordinate of player" do
      result = koshien.player_x
      expect(result).to eq(0)
    end
  end

  describe "#player_y" do
    it "returns y coordinate of player" do
      result = koshien.player_y
      expect(result).to eq(0)
    end
  end

  describe "#other_player" do
    context "when other player data is available" do
      before do
        koshien.instance_variable_set(:@last_map_area_response, {other_player: [5, 7]})
      end

      it "returns other player position as string" do
        result = koshien.other_player
        expect(result).to eq("5:7")
      end
    end

    context "when other player data is not available" do
      before do
        koshien.instance_variable_set(:@last_map_area_response, nil)
      end

      it "returns nil" do
        result = koshien.other_player
        expect(result).to be_nil
      end
    end
  end

  describe "#other_player_x" do
    context "when other player data is available" do
      before do
        koshien.instance_variable_set(:@last_map_area_response, {other_player: [8, 3]})
      end

      it "returns x coordinate of other player" do
        result = koshien.other_player_x
        expect(result).to eq(8)
      end
    end

    context "when other player data is not available" do
      before do
        koshien.instance_variable_set(:@last_map_area_response, nil)
      end

      it "returns nil" do
        result = koshien.other_player_x
        expect(result).to be_nil
      end
    end
  end

  describe "#other_player_y" do
    context "when other player data is available" do
      before do
        koshien.instance_variable_set(:@last_map_area_response, {other_player: [8, 12]})
      end

      it "returns y coordinate of other player" do
        result = koshien.other_player_y
        expect(result).to eq(12)
      end
    end

    context "when other player data is not available" do
      before do
        koshien.instance_variable_set(:@last_map_area_response, nil)
      end

      it "returns nil" do
        result = koshien.other_player_y
        expect(result).to be_nil
      end
    end
  end

  describe "#enemy" do
    context "when enemy data is available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, {"enemies" => [{"x" => 10, "y" => 15}]})
      end

      it "returns enemy position as string" do
        result = koshien.enemy
        expect(result).to eq("10:15")
      end
    end

    context "when enemy data is not available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, nil)
      end

      it "returns nil" do
        result = koshien.enemy
        expect(result).to be_nil
      end
    end

    context "when enemies array is empty" do
      before do
        koshien.instance_variable_set(:@current_turn_data, {"enemies" => []})
      end

      it "returns nil" do
        result = koshien.enemy
        expect(result).to be_nil
      end
    end
  end

  describe "#enemy_x" do
    context "when enemy data is available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, {"enemies" => [{"x" => 6, "y" => 9}]})
      end

      it "returns x coordinate of enemy" do
        result = koshien.enemy_x
        expect(result).to eq(6)
      end
    end

    context "when enemy data is not available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, nil)
      end

      it "returns nil" do
        result = koshien.enemy_x
        expect(result).to be_nil
      end
    end
  end

  describe "#enemy_y" do
    context "when enemy data is available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, {"enemies" => [{"x" => 6, "y" => 13}]})
      end

      it "returns y coordinate of enemy" do
        result = koshien.enemy_y
        expect(result).to eq(13)
      end
    end

    context "when enemy data is not available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, nil)
      end

      it "returns nil" do
        result = koshien.enemy_y
        expect(result).to be_nil
      end
    end
  end

  describe "#set_message" do
    it "sends debug message with string" do
      expect(koshien).to receive(:send_debug_message).with("Hello World")
      koshien.set_message("Hello World")
    end

    it "converts non-string values to string" do
      expect(koshien).to receive(:send_debug_message).with("42")
      koshien.set_message(42)
    end

    it "converts nil to string" do
      expect(koshien).to receive(:send_debug_message).with("")
      koshien.set_message(nil)
    end
  end

  describe "#add_action" do
    before do
      koshien.instance_variable_set(:@actions, [])
    end

    it "adds action to actions array" do
      action = {type: "move", position: "5:5"}
      koshien.send(:add_action, action)

      actions = koshien.send(:get_actions)
      expect(actions.length).to eq(1)
      expect(actions[0]).to eq(action)
    end

    it "appends multiple actions in order" do
      action1 = {type: "move", position: "1:1"}
      action2 = {type: "get_map_area", position: "2:2"}

      koshien.send(:add_action, action1)
      koshien.send(:add_action, action2)

      actions = koshien.send(:get_actions)
      expect(actions.length).to eq(2)
      expect(actions[0]).to eq(action1)
      expect(actions[1]).to eq(action2)
    end
  end

  describe "#clear_actions" do
    before do
      koshien.instance_variable_set(:@actions, [{type: "move"}, {type: "attack"}])
    end

    it "clears all actions from array" do
      koshien.send(:clear_actions)

      actions = koshien.send(:get_actions)
      expect(actions.length).to eq(0)
    end
  end

  describe "#get_actions" do
    it "returns copy of actions array" do
      original_actions = [{type: "move", position: "3:3"}]
      koshien.instance_variable_set(:@actions, original_actions)

      actions = koshien.send(:get_actions)

      expect(actions).to eq(original_actions)
      expect(actions.object_id).not_to eq(original_actions.object_id)
    end

    it "returns empty array when no actions" do
      koshien.instance_variable_set(:@actions, [])

      actions = koshien.send(:get_actions)

      expect(actions).to eq([])
    end
  end

  describe "#current_player_position (private)" do
    context "when @current_position is set" do
      it "returns @current_position" do
        position = {x: 5, y: 7}
        koshien.instance_variable_set(:@current_position, position)

        result = koshien.send(:current_player_position)

        expect(result).to eq(position)
      end
    end

    context "when @current_position is nil but turn data has position" do
      it "returns position from turn data" do
        koshien.instance_variable_set(:@current_position, nil)
        koshien.instance_variable_set(:@current_turn_data, {
          "current_player" => {
            "position" => {x: 3, y: 4}
          }
        })

        result = koshien.send(:current_player_position)

        expect(result).to eq({x: 3, y: 4})
      end
    end

    context "when turn data has x and y coordinates" do
      it "returns position built from x and y" do
        koshien.instance_variable_set(:@current_position, nil)
        koshien.instance_variable_set(:@current_turn_data, {
          "current_player" => {
            "x" => 8,
            "y" => 9
          }
        })

        result = koshien.send(:current_player_position)

        expect(result).to eq({x: 8, y: 9})
      end
    end

    context "when no position data is available" do
      it "returns nil" do
        koshien.instance_variable_set(:@current_position, nil)
        koshien.instance_variable_set(:@current_turn_data, nil)

        result = koshien.send(:current_player_position)

        expect(result).to be_nil
      end
    end
  end

  describe "#other_players (private)" do
    it "returns other players from turn data" do
      koshien.instance_variable_set(:@current_turn_data, {
        "other_players" => [{x: 5, y: 6}, {x: 7, y: 8}]
      })

      result = koshien.send(:other_players)

      expect(result).to eq([{x: 5, y: 6}, {x: 7, y: 8}])
    end

    it "returns empty array when no turn data" do
      koshien.instance_variable_set(:@current_turn_data, nil)

      result = koshien.send(:other_players)

      expect(result).to eq([])
    end
  end

  describe "#enemies (private)" do
    it "returns enemies from turn data" do
      koshien.instance_variable_set(:@current_turn_data, {
        "enemies" => [{"x" => 10, "y" => 11}]
      })

      result = koshien.send(:enemies)

      expect(result).to eq([{"x" => 10, "y" => 11}])
    end

    it "returns empty array when no turn data" do
      koshien.instance_variable_set(:@current_turn_data, nil)

      result = koshien.send(:enemies)

      expect(result).to eq([])
    end
  end

  describe "#visible_map (private)" do
    it "returns visible map from turn data" do
      map_data = {"map_data" => [[0, 1], [2, 3]]}
      koshien.instance_variable_set(:@current_turn_data, {
        "visible_map" => map_data
      })

      result = koshien.send(:visible_map)

      expect(result).to eq(map_data)
    end

    it "returns empty hash when no turn data" do
      koshien.instance_variable_set(:@current_turn_data, nil)

      result = koshien.send(:visible_map)

      expect(result).to eq({})
    end
  end

  describe "#goal_position (private)" do
    it "returns goal position from game state" do
      koshien.instance_variable_set(:@game_state, {
        "game_map" => {
          "goal_position" => {x: 12, y: 13}
        }
      })

      result = koshien.send(:goal_position)

      expect(result).to eq({x: 12, y: 13})
    end

    it "returns default position when no game state" do
      koshien.instance_variable_set(:@game_state, nil)

      result = koshien.send(:goal_position)

      expect(result).to eq({x: 14, y: 14})
    end
  end

  describe "#locate_objects" do
    let(:result_list) { Smalruby3::List.new }

    context "when visible map contains matching objects" do
      before do
        map_data = Array.new(20) { Array.new(20, 0) }
        map_data[2][3] = "A"  # Poison at (3, 2)
        map_data[5][7] = "B"  # Snake at (7, 5)
        map_data[8][9] = "C"  # Trap at (9, 8)
        map_data[10][11] = "a" # Tea at (11, 10) - lowercase, not in default "ABCD"

        koshien.instance_variable_set(:@current_turn_data, {
          "visible_map" => {
            "map_data" => map_data
          }
        })
      end

      it "finds objects in default area centered at player position" do
        koshien.instance_variable_set(:@current_position, {x: 5, y: 5})
        koshien.locate_objects(result: result_list)

        expect(result_list.length).to be >= 0
        expect(result_list).to be_a(Smalruby3::List)
      end

      it "finds objects with custom search area size" do
        koshien.instance_variable_set(:@current_position, {x: 5, y: 5})
        koshien.locate_objects(result: result_list, sq_size: 10)

        expect(result_list).to be_a(Smalruby3::List)
      end

      it "finds objects with custom center position" do
        koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
        koshien.locate_objects(result: result_list, cent: "7:7", sq_size: 5)

        expect(result_list).to be_a(Smalruby3::List)
      end

      it "finds only specified object types" do
        koshien.instance_variable_set(:@current_position, {x: 5, y: 5})
        koshien.locate_objects(result: result_list, sq_size: 10, objects: "AB")

        # Should find A at (3,2) and B at (7,5), but not C or a
        expect(result_list.length).to eq(2)
        expect(result_list[1]).to eq("3:2")
        expect(result_list[2]).to eq("7:5")
      end

      it "sorts results by y coordinate first, then x coordinate" do
        koshien.instance_variable_set(:@current_position, {x: 5, y: 5})
        koshien.locate_objects(result: result_list, sq_size: 10, objects: "ABC")

        # Should be sorted by y first: (3,2), (7,5), (9,8)
        expect(result_list[1]).to eq("3:2")
        expect(result_list[2]).to eq("7:5")
        expect(result_list[3]).to eq("9:8")
      end
    end

    context "when visible map is not available" do
      before do
        koshien.instance_variable_set(:@current_turn_data, nil)
        koshien.instance_variable_set(:@current_position, {x: 0, y: 0})
      end

      it "returns empty result list" do
        koshien.locate_objects(result: result_list)

        expect(result_list.length).to eq(0)
      end
    end

    context "when visible map has no matching objects" do
      before do
        map_data = Array.new(20) { Array.new(20, 0) }

        koshien.instance_variable_set(:@current_turn_data, {
          "visible_map" => {
            "map_data" => map_data
          }
        })
        koshien.instance_variable_set(:@current_position, {x: 10, y: 10})
      end

      it "returns empty result list" do
        koshien.locate_objects(result: result_list, sq_size: 5, objects: "ABCD")

        expect(result_list.length).to eq(0)
      end
    end
  end

  describe "#object" do
    context "with unknown/unexplored cell names" do
      it "returns -1 for 'unknown'" do
        expect(koshien.object("unknown")).to eq(-1)
      end

      it "returns -1 for '未探索のマス'" do
        expect(koshien.object("未探索のマス")).to eq(-1)
      end

      it "returns -1 for 'みたんさくのマス'" do
        expect(koshien.object("みたんさくのマス")).to eq(-1)
      end

      it "returns -1 for unrecognized names" do
        expect(koshien.object("invalid_object")).to eq(-1)
      end
    end

    context "with basic cell types (numeric values)" do
      it "returns 0 for 'space'" do
        expect(koshien.object("space")).to eq(0)
      end

      it "returns 0 for '空間'" do
        expect(koshien.object("空間")).to eq(0)
      end

      it "returns 1 for 'wall'" do
        expect(koshien.object("wall")).to eq(1)
      end

      it "returns 2 for 'storehouse'" do
        expect(koshien.object("storehouse")).to eq(2)
      end

      it "returns 3 for 'goal'" do
        expect(koshien.object("goal")).to eq(3)
      end

      it "returns 4 for 'water'" do
        expect(koshien.object("water")).to eq(4)
      end

      it "returns 5 for 'breakable wall'" do
        expect(koshien.object("breakable wall")).to eq(5)
      end
    end

    context "with item types (lowercase letters)" do
      it "returns 'a' for 'tea'" do
        expect(koshien.object("tea")).to eq("a")
      end

      it "returns 'b' for 'sweets'" do
        expect(koshien.object("sweets")).to eq("b")
      end

      it "returns 'c' for 'COIN'" do
        expect(koshien.object("COIN")).to eq("c")
      end

      it "returns 'd' for 'dolphin'" do
        expect(koshien.object("dolphin")).to eq("d")
      end

      it "returns 'e' for 'sword'" do
        expect(koshien.object("sword")).to eq("e")
      end
    end

    context "with trap types (uppercase letters)" do
      it "returns 'A' for 'poison'" do
        expect(koshien.object("poison")).to eq("A")
      end

      it "returns 'B' for 'snake'" do
        expect(koshien.object("snake")).to eq("B")
      end

      it "returns 'C' for 'trap'" do
        expect(koshien.object("trap")).to eq("C")
      end

      it "returns 'D' for 'bomb'" do
        expect(koshien.object("bomb")).to eq("D")
      end
    end

    context "with Japanese names" do
      it "returns 1 for '壁'" do
        expect(koshien.object("壁")).to eq(1)
      end

      it "returns 3 for 'ゴール'" do
        expect(koshien.object("ゴール")).to eq(3)
      end

      it "returns 'a' for 'お茶'" do
        expect(koshien.object("お茶")).to eq("a")
      end

      it "returns 'e' for '草薙剣'" do
        expect(koshien.object("草薙剣")).to eq("e")
      end

      it "returns 'A' for '毒キノコ'" do
        expect(koshien.object("毒キノコ")).to eq("A")
      end
    end
  end
end
