# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::Koshien, type: :model do
  let(:koshien) { Smalruby3::Koshien.instance }
  let(:result_list) { List.new }

  describe "#calc_route" do
    context "in mock mode" do
      before do
        ENV["KOSHIEN_MOCK_MODE"] = "true"
      end

      after do
        ENV.delete("KOSHIEN_MOCK_MODE")
      end

      it "returns a simple direct path" do
        koshien = Smalruby3::Koshien.instance

        koshien.calc_route(result: result_list, src: "1:1", dst: "3:3")

        expect(result_list.length).to eq(2)
        expect(result_list[1]).to eq("1:1")
        expect(result_list[2]).to eq("3:3")
      end
    end

    context "in production mode with mock game state" do
      before do
        ENV.delete("KOSHIEN_MOCK_MODE")

        # Mock the build_map_data_from_game_state to return a simple 5x5 map
        simple_map = Array.new(5) { Array.new(5, 0) }  # All open spaces
        allow(koshien).to receive(:build_map_data_from_game_state).and_return(simple_map)
      end

      it "calculates a route using Dijkstra pathfinding" do
        koshien.calc_route(result: result_list, src: "0:0", dst: "2:2")

        expect(result_list.length).to be >= 2
        expect(result_list[1]).to eq("0:0")  # Should start at source
        expect(result_list[result_list.length]).to eq("2:2")  # Should end at destination
      end

      it "handles routes with obstacles" do
        # Create a map with walls blocking direct path
        map_with_walls = Array.new(5) { Array.new(5, 0) }
        map_with_walls[1][1] = 2  # Wall at (1,1)
        map_with_walls[1][2] = 2  # Wall at (1,2)

        allow(koshien).to receive(:build_map_data_from_game_state).and_return(map_with_walls)

        koshien.calc_route(result: result_list, src: "0:0", dst: "2:2")

        expect(result_list.length).to be >= 3  # Should find alternate route
        expect(result_list[1]).to eq("0:0")
        expect(result_list[result_list.length]).to eq("2:2")
      end

      it "handles except_cells parameter" do
        except_cells = ["1:1", "1:2"]

        koshien.calc_route(result: result_list, src: "0:0", dst: "2:2", except_cells: except_cells)

        expect(result_list.length).to be >= 2
        expect(result_list[1]).to eq("0:0")
        expect(result_list[result_list.length]).to eq("2:2")

        # Check that the route doesn't pass through except_cells
        route_positions = (1..result_list.length).map { |i| result_list[i] }
        expect(route_positions).not_to include("1:1")
        expect(route_positions).not_to include("1:2")
      end

      it "calculates route from current position to goal (goal AI pattern)" do
        # Simulate goal AI scenario: player at (1,1) wants to reach goal at (14,14)
        large_map = Array.new(20) { Array.new(20, 0) }  # 20x20 open map
        allow(koshien).to receive(:build_map_data_from_game_state).and_return(large_map)

        koshien.calc_route(result: result_list, src: "1:1", dst: "14:14")

        expect(result_list.length).to be >= 2
        expect(result_list[1]).to eq("1:1")  # Start position
        expect(result_list[result_list.length]).to eq("14:14")  # Goal position

        # The second element should be a neighboring cell to (1,1)
        second_pos = result_list[2]
        expect(second_pos).to match(/^[0-2]:[0-2]$/)  # Adjacent to (1,1)
      end
    end

    describe "helper methods" do
      describe "#parse_position_string" do
        it "parses coordinate strings correctly" do
          result = koshien.send(:parse_position_string, "5:7")
          expect(result).to eq([5, 7])
        end

        it "handles invalid strings gracefully" do
          result = koshien.send(:parse_position_string, "invalid")
          expect(result).to eq([0, 0])
        end
      end

      describe "#make_data" do
        it "builds graph data for pathfinding" do
          simple_map = [
            [0, 0, 2],
            [0, 0, 0],
            [2, 0, 0]
          ]

          result = koshien.send(:make_data, simple_map, [])

          expect(result).to be_a(Hash)
          expect(result).to have_key("m0_0")
          expect(result["m0_0"]).to be_an(Array)
        end

        it "respects except_cells" do
          simple_map = [
            [0, 0, 0],
            [0, 0, 0],
            [0, 0, 0]
          ]
          except_cells = [[1, 1]]

          graph_data = koshien.send(:make_data, simple_map, except_cells)

          # Original map should NOT be modified (uses deep copy)
          expect(simple_map[1][1]).to eq(0)

          # But graph should not have edges to (1,1) since it's treated as a wall
          # Check that adjacent nodes don't connect to m1_1
          expect(graph_data["m0_1"]).not_to include(have_attributes(nid: "m1_1"))
          expect(graph_data["m1_0"]).not_to include(have_attributes(nid: "m1_1"))
          expect(graph_data["m2_1"]).not_to include(have_attributes(nid: "m1_1"))
          expect(graph_data["m1_2"]).not_to include(have_attributes(nid: "m1_1"))
        end
      end
    end

    describe "DijkstraSearch module" do
      let(:simple_graph_data) do
        {
          "m0_0" => [[1, "m0_1"], [1, "m1_0"]],
          "m0_1" => [[1, "m0_0"], [1, "m1_1"]],
          "m1_0" => [[1, "m0_0"], [1, "m1_1"]],
          "m1_1" => [[1, "m0_1"], [1, "m1_0"]]
        }
      end

      it "finds the shortest path between two points" do
        graph = DijkstraSearch::Graph.new(simple_graph_data)
        route = graph.get_route("m0_0", "m1_1")

        expect(route).to be_an(Array)
        expect(route.first).to eq([0, 0])
        expect(route.last).to eq([1, 1])
        expect(route.length).to be >= 2
      end

      it "handles unreachable destinations" do
        # Create isolated nodes
        isolated_graph = {
          "m0_0" => [[1, "m0_1"]],
          "m0_1" => [[1, "m0_0"]],
          "m2_2" => [[1, "m2_3"]],
          "m2_3" => [[1, "m2_2"]]
        }

        graph = DijkstraSearch::Graph.new(isolated_graph)
        route = graph.get_route("m0_0", "m2_2")

        # When destination is unreachable, should return only starting position
        expect(route).to be_an(Array)
        expect(route.length).to eq(1)
        expect(route.first).to eq([0, 0])
      end
    end
  end
end
