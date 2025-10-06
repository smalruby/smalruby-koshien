# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::KoshienMock do
  let(:mock) { described_class.instance }

  describe "#connect_game" do
    it "sets player name" do
      expect { mock.connect_game(name: "test_player") }.to output(/test_player/).to_stdout
    end
  end

  describe "#get_map_area" do
    it "returns nil" do
      expect(mock.get_map_area("5:5")).to be_nil
    end
  end

  describe "#move_to" do
    it "logs movement" do
      expect { mock.move_to("10:10") }.to output(/Move to/).to_stdout
    end
  end

  describe "#turn_over" do
    it "logs turn over" do
      expect { mock.turn_over }.to output(/Turn over/).to_stdout
    end
  end

  describe "#set_dynamite" do
    it "logs dynamite placement" do
      expect { mock.set_dynamite("7:7") }.to output(/Set dynamite/).to_stdout
    end
  end

  describe "#set_bomb" do
    it "logs bomb placement" do
      expect { mock.set_bomb("8:8") }.to output(/Set bomb/).to_stdout
    end
  end

  describe "#calc_route" do
    it "returns route with default parameters" do
      result = Smalruby3::List.new
      mock.calc_route(result: result)
      expect(result.length).to eq(2)  # Simple stub returns [src, dst]
    end

    it "accepts optional parameters" do
      result = Smalruby3::List.new
      mock.calc_route(
        result: result,
        src: "1:1",
        dst: "10:10",
        except_cells: ["5:5"]
      )
      expect(result.length).to eq(2)
      expect(result[1]).to eq("1:1")
      expect(result[2]).to eq("10:10")
    end
  end

  describe "#map" do
    it "returns -1 for unexplored" do
      expect(mock.map("5:5")).to eq(-1)
    end
  end

  describe "#map_all" do
    it "returns 15x15 grid string" do
      result = mock.map_all
      expect(result).to be_a(String)
      rows = result.split(",")
      expect(rows.length).to eq(15)
      expect(rows.first.length).to eq(15)
    end
  end

  describe "#other_player" do
    it "returns nil" do
      expect(mock.other_player).to be_nil
    end
  end

  describe "#other_player_x" do
    it "returns nil" do
      expect(mock.other_player_x).to be_nil
    end
  end

  describe "#other_player_y" do
    it "returns nil" do
      expect(mock.other_player_y).to be_nil
    end
  end

  describe "#enemy" do
    it "returns nil" do
      expect(mock.enemy).to be_nil
    end
  end

  describe "#enemy_x" do
    it "returns nil" do
      expect(mock.enemy_x).to be_nil
    end
  end

  describe "#enemy_y" do
    it "returns nil" do
      expect(mock.enemy_y).to be_nil
    end
  end

  describe "#goal" do
    it "returns default goal position" do
      expect(mock.goal).to eq("14:14")
    end
  end

  describe "#goal_x" do
    it "returns 14" do
      expect(mock.goal_x).to eq(14)
    end
  end

  describe "#goal_y" do
    it "returns 14" do
      expect(mock.goal_y).to eq(14)
    end
  end

  describe "#player" do
    it "returns default position" do
      expect(mock.player).to eq("0:0")
    end
  end

  describe "#player_x" do
    it "returns 0" do
      expect(mock.player_x).to eq(0)
    end
  end

  describe "#player_y" do
    it "returns 0" do
      expect(mock.player_y).to eq(0)
    end
  end

  describe "#set_message" do
    it "logs message" do
      expect { mock.set_message("test message") }.to output(/test message/).to_stdout
    end
  end

  describe "#locate_objects" do
    it "returns empty list and logs message" do
      result = Smalruby3::List.new
      expect { mock.locate_objects(result: result) }.to output(/Locate objects/).to_stdout
      expect(result.length).to eq(0)
    end

    it "accepts optional parameters and logs message" do
      result = Smalruby3::List.new
      expect {
        mock.locate_objects(
          result: result,
          cent: "7:7",
          sq_size: 15,
          objects: "ABCD"
        )
      }.to output(/Locate objects.*cent=7:7.*sq_size=15.*objects=ABCD/).to_stdout
      expect(result.length).to eq(0)
    end
  end

  describe "#map_from" do
    it "returns -1 for unknown" do
      expect(mock.map_from("5:5", "test")).to eq(-1)
    end
  end

  describe "#position_of_x" do
    it "extracts x coordinate" do
      expect(mock.position_of_x("7:9")).to eq(7)
    end
  end

  describe "#position_of_y" do
    it "extracts y coordinate" do
      expect(mock.position_of_y("7:9")).to eq(9)
    end
  end

  describe "#object" do
    it "returns value for unknown" do
      expect(mock.object("unknown")).to eq(-1)
    end

    it "returns value for space" do
      expect(mock.object("space")).to eq(0)
    end

    it "returns value for wall" do
      expect(mock.object("wall")).to eq(1)
    end

    it "returns value for water" do
      expect(mock.object("water")).to eq(4)
    end

    it "returns -1 for unrecognized object" do
      expect(mock.object("invalid")).to eq(-1)
    end
  end

  describe "#position" do
    it "formats x and y as position string" do
      expect(mock.position(5, 10)).to eq("5:10")
    end
  end

  describe "#parse_position_string" do
    it "parses position string to coordinates" do
      coords = mock.send(:parse_position_string, "7:9")
      expect(coords).to eq([7, 9])
    end

    it "handles nil input" do
      coords = mock.send(:parse_position_string, nil)
      expect(coords).to eq([0, 0])
    end
  end
end
