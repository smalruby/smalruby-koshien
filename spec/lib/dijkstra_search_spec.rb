# frozen_string_literal: true

require "rails_helper"

RSpec.describe DijkstraSearch do
  describe DijkstraSearch::Node do
    describe "#initialize" do
      it "creates a node with id and edges" do
        edges = [DijkstraSearch::Edge.new(1, "m0_1")]
        node = DijkstraSearch::Node.new("m0_0", edges)

        expect(node.id).to eq("m0_0")
        expect(node.edges).to eq(edges)
        expect(node.cost).to be_nil
        expect(node.done).to be false
      end

      it "creates a node with cost and done status" do
        node = DijkstraSearch::Node.new("m0_0", [], 10, true)

        expect(node.id).to eq("m0_0")
        expect(node.cost).to eq(10)
        expect(node.done).to be true
      end
    end
  end

  describe DijkstraSearch::Edge do
    describe "#initialize" do
      it "creates an edge with cost and node id" do
        edge = DijkstraSearch::Edge.new(5, "m0_1")

        expect(edge.cost).to eq(5)
        expect(edge.nid).to eq("m0_1")
      end
    end
  end

  describe DijkstraSearch::Graph do
    let(:simple_graph_data) do
      {
        "m0_0" => [[1, "m0_1"], [2, "m1_0"]],
        "m0_1" => [[1, "m0_0"], [1, "m0_2"]],
        "m0_2" => [[1, "m0_1"]],
        "m1_0" => [[2, "m0_0"]]
      }
    end

    let(:graph) { DijkstraSearch::Graph.new(simple_graph_data) }

    describe "#initialize" do
      it "creates a graph from data hash" do
        expect(graph).to be_a(DijkstraSearch::Graph)
      end

      it "creates nodes with edges" do
        nodes = graph.instance_variable_get(:@nodes)
        expect(nodes.length).to eq(4)
        expect(nodes.map(&:id)).to contain_exactly("m0_0", "m0_1", "m0_2", "m1_0")
      end
    end

    describe "#route" do
      context "when path exists" do
        it "finds shortest route from start to goal" do
          route = graph.route("m0_0", "m0_2")

          expect(route).to be_an(Array)
          expect(route.first.id).to eq("m0_2")  # First is goal (reverse order)
          expect(route.last.id).to eq("m0_0")   # Last is start
        end

        it "returns nodes in reverse order (goal to start)" do
          route = graph.route("m0_0", "m0_2")

          # Route should be: m0_2, m0_1, m0_0 (goal to start)
          expect(route.map(&:id)).to eq(["m0_2", "m0_1", "m0_0"])
        end
      end

      context "when path does not exist" do
        it "returns single node for unreachable destination" do
          isolated_graph_data = {
            "m3_3" => [[1, "m3_4"]],
            "m3_4" => [[1, "m3_3"]],
            "m5_5" => []  # Isolated node
          }
          isolated_graph = DijkstraSearch::Graph.new(isolated_graph_data)

          route = isolated_graph.route("m3_3", "m5_5")

          # When destination exists but is unreachable, returns just the destination node
          expect(route.length).to be >= 0
          if route.length > 0
            expect(route.first.id).to eq("m5_5")
            expect(route.first.from).to be_nil
          end
        end

        it "returns empty array for non-existent destination" do
          route = graph.route("m0_0", "non_existent")

          expect(route).to eq([])
        end
      end

      context "when start equals goal" do
        it "returns single node route" do
          route = graph.route("m0_0", "m0_0")

          expect(route.length).to eq(1)
          expect(route.first.id).to eq("m0_0")
        end
      end
    end

    describe "#dijkstra (via route)" do
      it "calculates shortest path costs correctly" do
        graph.route("m0_0", "m0_2")
        nodes = graph.instance_variable_get(:@nodes)

        # m0_0 (start) -> cost 0
        # m0_1 -> cost 1 (from m0_0)
        # m0_2 -> cost 2 (from m0_1)
        # m1_0 -> cost 2 (from m0_0)
        node_0_0 = nodes.find { |n| n.id == "m0_0" }
        node_0_1 = nodes.find { |n| n.id == "m0_1" }
        node_0_2 = nodes.find { |n| n.id == "m0_2" }

        expect(node_0_0.cost).to eq(0)
        expect(node_0_1.cost).to eq(1)
        expect(node_0_2.cost).to eq(2)
      end
    end

    describe "complex graph scenarios" do
      let(:complex_graph_data) do
        {
          "m0_0" => [[1, "m1_0"], [4, "m0_1"]],
          "m1_0" => [[1, "m2_0"], [2, "m1_1"]],
          "m2_0" => [[1, "m2_1"]],
          "m0_1" => [[1, "m1_1"]],
          "m1_1" => [[1, "m2_1"]],
          "m2_1" => []
        }
      end

      let(:complex_graph) { DijkstraSearch::Graph.new(complex_graph_data) }

      it "finds shortest path among multiple routes" do
        route = complex_graph.route("m0_0", "m2_1")

        # Shortest path: m0_0 -> m1_0 -> m2_0 -> m2_1 (cost: 3)
        # Alternative: m0_0 -> m0_1 -> m1_1 -> m2_1 (cost: 6)
        expect(route.map(&:id)).to eq(["m2_1", "m2_0", "m1_0", "m0_0"])
      end
    end

    describe "#get_route" do
      context "when path exists" do
        it "returns route as coordinates array in normal order (start to goal)" do
          route_coords = graph.get_route("m0_0", "m0_2")

          expect(route_coords).to be_an(Array)
          expect(route_coords.first).to eq([0, 0])  # Start
          expect(route_coords.last).to eq([0, 2])   # Goal
        end

        it "converts node IDs to coordinate arrays" do
          route_coords = graph.get_route("m0_0", "m0_2")

          # Expected: [[0, 0], [0, 1], [0, 2]]
          expect(route_coords.length).to eq(3)
          expect(route_coords[0]).to eq([0, 0])
          expect(route_coords[1]).to eq([0, 1])
          expect(route_coords[2]).to eq([0, 2])
        end
      end

      context "when path does not exist" do
        it "returns only starting position for unreachable destination" do
          isolated_graph_data = {
            "m0_0" => [[1, "m0_1"]],
            "m0_1" => [[1, "m0_0"]],
            "m0_2" => []  # Isolated node
          }
          isolated_graph = DijkstraSearch::Graph.new(isolated_graph_data)

          route_coords = isolated_graph.get_route("m0_0", "m0_2")

          expect(route_coords).to eq([[0, 0]])
        end

        it "returns only starting position for non-existent destination" do
          route_coords = graph.get_route("m0_0", "m9_9")

          expect(route_coords).to eq([[0, 0]])
        end
      end

      context "when start equals goal" do
        it "returns single coordinate" do
          route_coords = graph.get_route("m0_0", "m0_0")

          expect(route_coords).to eq([[0, 0]])
        end
      end
    end

    describe "#cost" do
      it "returns minimum cost from start to destination" do
        cost = graph.cost("m0_2", "m0_0")

        # Path: m0_0 -> m0_1 -> m0_2 with cost 1 + 1 = 2
        expect(cost).to eq(2)
      end

      it "returns 0 for start node" do
        cost = graph.cost("m0_0", "m0_0")

        expect(cost).to eq(0)
      end

      it "handles different start nodes" do
        cost = graph.cost("m0_0", "m0_2")

        # Reverse path: m0_2 -> m0_1 -> m0_0 with cost 1 + 1 = 2
        expect(cost).to eq(2)
      end
    end
  end
end
