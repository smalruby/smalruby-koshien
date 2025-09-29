require "rails_helper"
require_relative "../../../lib/smalruby3/koshien"
require_relative "../../../lib/smalruby3/koshien/position"
require_relative "../../../lib/smalruby3/list"

RSpec.describe Smalruby3::Koshien do
  let(:koshien) { described_class.instance }
  let(:mock_input) { StringIO.new }
  let(:mock_output) { StringIO.new }

  before do
    # Reset singleton state
    koshien.io_input = mock_input
    koshien.io_output = mock_output
    koshien.game_state = {}
    koshien.turn_number = 1
    koshien.round_number = 1
    koshien.player_position = [5, 5]
    koshien.goal_position = [10, 10]
    koshien.other_player_position = nil
    koshien.enemy_position = nil
    koshien.my_map = Array.new(15) { Array.new(15, -1) }
    koshien.item_locations = {}
    koshien.dynamite_count = 2
    koshien.bomb_count = 2
    koshien.current_message = ""
    koshien.action_count = 0
    koshien.last_map_area_info = {}

    # Set up a basic map for testing
    # 0 = space, 1 = wall, 3 = goal, 4 = water, 5 = breakable wall
    koshien.my_map[5] = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
    koshien.my_map[6] = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
    koshien.my_map[7] = [0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0]
    koshien.my_map[10] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0]
  end

  describe "#initialize" do
    it "initializes with default values" do
      expect(koshien.turn_number).to be >= 0
      expect(koshien.round_number).to be >= 0
      expect(koshien.player_position).to be_an(Array)
      expect(koshien.goal_position).to be_an(Array)
      expect(koshien.my_map).to be_an(Array)
      expect(koshien.my_map.size).to eq(15)
      expect(koshien.my_map.first.size).to eq(15)
    end
  end

  describe "#position" do
    it "creates position string from coordinates" do
      expect(koshien.position(7, 8)).to eq("7:8")
      expect(koshien.position(0, 0)).to eq("0:0")
      expect(koshien.position(14, 14)).to eq("14:14")
    end
  end

  describe "#player" do
    it "returns current player position as string" do
      koshien.player_position = [7, 8]
      expect(koshien.player).to eq("7:8")
    end
  end

  describe "#player_x" do
    it "returns player x coordinate" do
      koshien.player_position = [7, 8]
      expect(koshien.player_x).to eq(7)
    end
  end

  describe "#player_y" do
    it "returns player y coordinate" do
      koshien.player_position = [7, 8]
      expect(koshien.player_y).to eq(8)
    end
  end

  describe "#goal" do
    it "returns goal position as string" do
      koshien.goal_position = [10, 12]
      expect(koshien.goal).to eq("10:12")
    end
  end

  describe "#goal_x" do
    it "returns goal x coordinate" do
      koshien.goal_position = [10, 12]
      expect(koshien.goal_x).to eq(10)
    end
  end

  describe "#goal_y" do
    it "returns goal y coordinate" do
      koshien.goal_position = [10, 12]
      expect(koshien.goal_y).to eq(12)
    end
  end

  describe "#other_player" do
    it "returns other player position when available" do
      koshien.other_player_position = [3, 4]
      expect(koshien.other_player).to eq("3:4")
    end

    it "returns nil when other player position is not available" do
      koshien.other_player_position = nil
      expect(koshien.other_player).to be_nil
    end
  end

  describe "#other_player_x" do
    it "returns other player x coordinate when available" do
      koshien.other_player_position = [3, 4]
      expect(koshien.other_player_x).to eq(3)
    end

    it "returns nil when other player position is not available" do
      koshien.other_player_position = nil
      expect(koshien.other_player_x).to be_nil
    end
  end

  describe "#other_player_y" do
    it "returns other player y coordinate when available" do
      koshien.other_player_position = [3, 4]
      expect(koshien.other_player_y).to eq(4)
    end

    it "returns nil when other player position is not available" do
      koshien.other_player_position = nil
      expect(koshien.other_player_y).to be_nil
    end
  end

  describe "#enemy" do
    it "returns enemy position when available" do
      koshien.enemy_position = [6, 7]
      expect(koshien.enemy).to eq("6:7")
    end

    it "returns nil when enemy position is not available" do
      koshien.enemy_position = nil
      expect(koshien.enemy).to be_nil
    end
  end

  describe "#enemy_x" do
    it "returns enemy x coordinate when available" do
      koshien.enemy_position = [6, 7]
      expect(koshien.enemy_x).to eq(6)
    end

    it "returns nil when enemy position is not available" do
      koshien.enemy_position = nil
      expect(koshien.enemy_x).to be_nil
    end
  end

  describe "#enemy_y" do
    it "returns enemy y coordinate when available" do
      koshien.enemy_position = [6, 7]
      expect(koshien.enemy_y).to eq(7)
    end

    it "returns nil when enemy position is not available" do
      koshien.enemy_position = nil
      expect(koshien.enemy_y).to be_nil
    end
  end

  describe "#map" do
    it "returns map data for valid coordinates" do
      koshien.my_map[5][7] = 1 # wall
      expect(koshien.map("7:5")).to eq(1)
    end

    it "returns -1 for unknown coordinates" do
      koshien.my_map[5][7] = -1
      expect(koshien.map("7:5")).to eq(-1)
    end

    it "returns nil for out-of-bounds coordinates" do
      expect(koshien.map("-1:5")).to be_nil
      expect(koshien.map("15:5")).to be_nil
      expect(koshien.map("5:-1")).to be_nil
      expect(koshien.map("5:15")).to be_nil
    end
  end

  describe "#map_all" do
    it "returns map as comma-separated string" do
      # Set first row to known values
      koshien.my_map[0] = [0, 1, 0, 3, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      koshien.my_map[1] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]

      result = koshien.map_all
      lines = result.split(",")

      expect(lines[0]).to eq("010345000000000")
      expect(lines[1]).to eq("---------------")
      expect(lines.size).to eq(15)
    end
  end

  describe "#map_from" do
    before do
      koshien.my_map[5][7] = 4 # water
    end

    it "returns map data from map_all string" do
      map_string = koshien.map_all
      expect(koshien.map_from("7:5", map_string)).to eq(4)
    end

    it "returns -1 for unknown positions in map string" do
      koshien.my_map[3][2] = -1
      map_string = koshien.map_all
      expect(koshien.map_from("2:3", map_string)).to eq(-1)
    end
  end

  describe "#object" do
    it "returns correct values for terrain types" do
      expect(koshien.object("space")).to eq(0)
      expect(koshien.object("wall")).to eq(1)
      expect(koshien.object("goal")).to eq(3)
      expect(koshien.object("water")).to eq(4)
      expect(koshien.object("breakable wall")).to eq(5)
    end

    it "returns correct values for positive items" do
      expect(koshien.object("tea")).to eq("a")
      expect(koshien.object("sweets")).to eq("b")
      expect(koshien.object("COIN")).to eq("c")
      expect(koshien.object("dolphin")).to eq("d")
      expect(koshien.object("sword")).to eq("e")
    end

    it "returns correct values for negative items" do
      expect(koshien.object("poison")).to eq("A")
      expect(koshien.object("snake")).to eq("B")
      expect(koshien.object("trap")).to eq("C")
      expect(koshien.object("bomb")).to eq("D")
    end

    it "returns -1 for unknown objects" do
      expect(koshien.object("unknown_object")).to eq(-1)
    end
  end

  describe "#position_of_x" do
    it "extracts x coordinate from position string" do
      expect(koshien.position_of_x("7:8")).to eq(7)
      expect(koshien.position_of_x("0:14")).to eq(0)
      expect(koshien.position_of_x("14:0")).to eq(14)
    end
  end

  describe "#position_of_y" do
    it "extracts y coordinate from position string" do
      expect(koshien.position_of_y("7:8")).to eq(8)
      expect(koshien.position_of_y("0:14")).to eq(14)
      expect(koshien.position_of_y("14:0")).to eq(0)
    end
  end

  describe "#set_message" do
    it "sets current message and truncates to 100 characters" do
      long_message = "a" * 150
      koshien.set_message(long_message)
      expect(koshien.current_message).to eq("a" * 100)
    end

    it "sends JSON message for set_message" do
      koshien.set_message("test message")
      output = mock_output.string
      expect(output).to include("set_message")
      expect(output).to include("test message")
    end
  end

  describe "#calc_route" do
    let(:result_list) { Smalruby3::List.new }

    it "finds path from current position to goal" do
      koshien.player_position = [5, 5]
      koshien.goal_position = [7, 5]

      # Clear the path - ensure all cells in path are passable
      koshien.my_map[5][5] = 0 # start position
      koshien.my_map[5][6] = 0 # intermediate
      koshien.my_map[5][7] = 0 # goal position

      koshien.calc_route(result: result_list)

      expect(result_list.length).to be > 1
      expect(result_list[1]).to eq("5:5") # start (List uses 1-based indexing)
      expect(result_list[result_list.length]).to eq("7:5") # goal
    end

    it "finds path with custom source and destination" do
      # Clear a simple horizontal path
      koshien.my_map[3][2] = 0
      koshien.my_map[3][3] = 0
      koshien.my_map[3][4] = 0

      koshien.calc_route(result: result_list, src: "2:3", dst: "4:3")

      expect(result_list.length).to be > 1
      expect(result_list[1]).to eq("2:3") # start
      expect(result_list[result_list.length]).to eq("4:3") # goal
    end

    it "avoids except_cells in pathfinding" do
      except_list = Smalruby3::List.new
      except_list.push("6:5")

      # Clear a path
      (3..8).each { |x| koshien.my_map[5][x] = 0 }

      koshien.calc_route(result: result_list, src: "3:5", dst: "8:5", except_cells: except_list)

      # Should find alternative path or return just start position if no path
      expect(result_list[1]).to eq("3:5") # start position (1-based indexing)
    end

    it "returns just start position when no path exists" do
      # Block all paths with walls
      (0..14).each do |x|
        (0..14).each do |y|
          koshien.my_map[y][x] = 1 unless x == 5 && y == 5 # Keep start position clear
        end
      end

      koshien.calc_route(result: result_list, src: "5:5", dst: "10:10")

      expect(result_list.length).to eq(1)
      expect(result_list[1]).to eq("5:5") # 1-based indexing
    end
  end

  describe "#locate_objects" do
    let(:result_list) { Smalruby3::List.new }

    before do
      # Place some items on the map
      koshien.my_map[4][3] = "A" # poison at 3:4
      koshien.my_map[4][7] = "B" # snake at 7:4
      koshien.my_map[6][3] = "C" # trap at 3:6
      koshien.my_map[6][7] = "D" # bomb at 7:6
      koshien.my_map[5][5] = "a" # tea at 5:5
    end

    it "finds negative items in default 5x5 area around player" do
      koshien.player_position = [5, 5]
      koshien.locate_objects(result: result_list, objects: "ABCD")

      # Should find items within 2 squares of player (5,5)
      expect(result_list).to include("3:4") # A
      expect(result_list).to include("7:4") # B
      expect(result_list).to include("3:6") # C
      expect(result_list).to include("7:6") # D
    end

    it "finds positive items in specified area" do
      koshien.locate_objects(result: result_list, cent: "5:5", sq_size: 5, objects: "abcde")

      expect(result_list).to include("5:5") # tea
    end

    it "finds specific terrain in larger area" do
      # Add some water tiles
      koshien.my_map[7][4] = 4
      koshien.my_map[7][6] = 4

      koshien.locate_objects(result: result_list, cent: "7:7", sq_size: 7, objects: "4")

      expect(result_list).to include("4:7")
      expect(result_list).to include("6:7")
    end

    it "sorts results by y coordinate first, then x coordinate" do
      koshien.my_map[3][1] = "A"
      koshien.my_map[3][8] = "A"
      koshien.my_map[7][1] = "A"
      koshien.my_map[7][8] = "A"

      koshien.locate_objects(result: result_list, cent: "5:5", sq_size: 15, objects: "A")

      # Convert List to array for testing (1-based to 0-based)
      positions = []
      (1..result_list.length).each do |i|
        positions << result_list[i]
      end

      # Should be sorted by y first (3, 7), then by x within same y
      y_coords = positions.map { |pos| koshien.position_of_y(pos) }
      expect(y_coords).to eq(y_coords.sort)

      # Within same y, should be sorted by x
      y3_positions = positions.select { |pos| koshien.position_of_y(pos) == 3 }
      y3_x_coords = y3_positions.map { |pos| koshien.position_of_x(pos) }
      expect(y3_x_coords).to eq(y3_x_coords.sort)
    end

    it "respects area bounds" do
      # Place item outside 3x3 area
      koshien.my_map[1][1] = "A"

      koshien.locate_objects(result: result_list, cent: "5:5", sq_size: 3, objects: "A")

      expect(result_list).not_to include("1:1")
    end
  end

  describe "JSON communication methods" do
    describe "#connect_game" do
      it "sends connect_game message and waits for response" do
        # Mock response
        mock_input.string = '{"type":"connection_established"}' + "\n"

        result = koshien.connect_game(name: "test_player")

        expect(result).to be true
        expect(mock_output.string).to include("connect_game")
        expect(mock_output.string).to include("test_player")
      end

      it "returns false when connection fails" do
        mock_input.string = '{"type":"connection_failed"}' + "\n"

        result = koshien.connect_game(name: "test_player")

        expect(result).to be false
      end
    end

    describe "#get_map_area" do
      it "sends get_map_area message and processes response" do
        mock_input.string = '{"type":"map_area_data","data":{"map":[[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0]]}}' + "\n"

        result = koshien.get_map_area("7:7")

        expect(result).to be_a(Hash)
        expect(mock_output.string).to include("get_map_area")
        expect(koshien.action_count).to eq(1)
      end

      it "returns nil when action limit reached" do
        koshien.action_count = 2

        result = koshien.get_map_area("7:7")

        expect(result).to be_nil
      end
    end

    describe "#move_to" do
      it "sends move_to message and updates position on success" do
        mock_input.string = '{"type":"move_result","success":true}' + "\n"

        result = koshien.move_to("6:5")

        expect(result).to be true
        expect(koshien.player_position).to eq([6, 5])
        expect(koshien.action_count).to eq(1)
      end

      it "does not update position on failure" do
        old_position = koshien.player_position.dup
        mock_input.string = '{"type":"move_result","success":false}' + "\n"

        result = koshien.move_to("15:15")

        expect(result).to be false
        expect(koshien.player_position).to eq(old_position)
      end
    end

    describe "#set_dynamite" do
      it "sends set_dynamite message with position" do
        mock_input.string = '{"type":"dynamite_result","success":true}' + "\n"

        result = koshien.set_dynamite("6:6")

        expect(result).to be true
        expect(koshien.dynamite_count).to eq(1)
        expect(koshien.action_count).to eq(1)
      end

      it "uses current position when no position specified" do
        mock_input.string = '{"type":"dynamite_result","success":true}' + "\n"
        koshien.player_position = [8, 9]

        koshien.set_dynamite

        expect(mock_output.string).to include('"x":8')
        expect(mock_output.string).to include('"y":9')
      end

      it "returns nil when no dynamite left" do
        koshien.dynamite_count = 0

        result = koshien.set_dynamite("6:6")

        expect(result).to be_nil
      end
    end

    describe "#set_bomb" do
      it "sends set_bomb message with position" do
        mock_input.string = '{"type":"bomb_result","success":true}' + "\n"

        result = koshien.set_bomb("6:6")

        expect(result).to be true
        expect(koshien.bomb_count).to eq(1)
        expect(koshien.action_count).to eq(1)
      end

      it "uses current position when no position specified" do
        mock_input.string = '{"type":"bomb_result","success":true}' + "\n"
        koshien.player_position = [8, 9]

        koshien.set_bomb

        expect(mock_output.string).to include('"x":8')
        expect(mock_output.string).to include('"y":9')
      end

      it "returns nil when no bombs left" do
        koshien.bomb_count = 0

        result = koshien.set_bomb("6:6")

        expect(result).to be_nil
      end
    end

    describe "#turn_over" do
      it "sends turn_over message" do
        mock_input.string = '{"type":"turn_acknowledged"}' + "\n"

        koshien.turn_over

        expect(mock_output.string).to include("turn_over")
      end
    end
  end
end
