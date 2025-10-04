# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::Koshien, type: :model do
  describe "#locate_objects" do
    let(:koshien) { described_class.instance }
    let(:result_list) { Smalruby3::List.new }

    before do
      # Ensure production mode (not mock mode)
      ENV.delete("KOSHIEN_MOCK_MODE")

      # Setup mock game state with known map data
      koshien.instance_variable_set(:@current_turn_data, {
        "visible_map" => {
          "map_data" => map_data
        }
      })
    end

    context "with negative items (ABCD) on map" do
      let(:map_data) do
        # 17x17 map with negative items at known positions
        Array.new(17) { Array.new(17, 0) }.tap do |map|
          # Add negative items (string marks):
          map[2][3] = "A"   # A (poison) at (3, 2)
          map[2][8] = "B"   # B (snake) at (8, 2)
          map[2][13] = "A"  # A (poison) at (13, 2)
          map[4][6] = "C"   # C (trap) at (6, 4)
          map[5][11] = "C"  # C (trap) at (11, 5)
          map[10][12] = "C" # C (trap) at (12, 10)
          map[13][8] = "D"  # D (bomb) at (8, 13)
          map[14][5] = "B"  # B (snake) at (5, 14)
          map[14][11] = "B" # B (snake) at (11, 14)
        end
      end

      it "finds all negative items in full map search" do
        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 17, objects: "ABCD")

        expect(result_list.length).to eq(9)

        # Check items are sorted by y, then x
        expected_positions = [
          "3:2", "8:2", "13:2",  # Row 2
          "6:4",                  # Row 4
          "11:5",                 # Row 5
          "12:10",                # Row 10
          "8:13",                 # Row 13
          "5:14", "11:14"         # Row 14
        ]

        expect(result_list.map(&:to_s)).to eq(expected_positions)
      end

      it "finds items in partial search area" do
        # Search center (7, 7) with size 5 (covers 5x5 area from 5,5 to 9,9)
        koshien.locate_objects(result: result_list, cent: "7:7", sq_size: 5, objects: "ABCD")

        # Only items at (8, 2) is outside the range, none should be found in 5x5 from (5,5)
        # Actually the center is (7,7), half_size=2, so range is (5,5) to (9,9)
        # Items in that range: none of the items fall in that exact range
        expect(result_list.length).to eq(0)
      end

      it "finds items near top-left area" do
        # Search center (7, 2) with size 15
        koshien.locate_objects(result: result_list, cent: "7:2", sq_size: 15, objects: "ABCD")

        # half_size = 7, so x: 0-14, y: 0-9
        # Items in range: (3,2), (8,2), (13,2), (6,4), (11,5)
        expect(result_list.length).to eq(5)
        expect(result_list[1]).to eq("3:2")
        expect(result_list[2]).to eq("8:2")
        expect(result_list[3]).to eq("13:2")
      end

      it "filters by specific item types" do
        # Search for only poison (A)
        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 17, objects: "A")

        expect(result_list.length).to eq(2)
        expect(result_list[1]).to eq("3:2")
        expect(result_list[2]).to eq("13:2")
      end

      it "filters by multiple specific types" do
        # Search for traps (C) and bombs (D)
        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 17, objects: "CD")

        expect(result_list.length).to eq(4)
        # 3 traps + 1 bomb
        expect(result_list.map(&:to_s)).to include("6:4", "11:5", "12:10", "8:13")
      end
    end

    context "with positive items (abcde) on map" do
      let(:map_data) do
        Array.new(17) { Array.new(17, 0) }.tap do |map|
          map[1][15] = "a"  # a (tea) at (15, 1)
          map[5][5] = "b"   # b (sweets) at (5, 5)
          map[8][12] = "b"  # b (sweets) at (12, 8)
          map[6][15] = "c"  # c (COIN) at (15, 6)
          map[10][1] = "c"  # c (COIN) at (1, 10)
        end
      end

      it "finds positive items when searching for them" do
        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 17, objects: "abc")

        expect(result_list.length).to eq(5)
        expect(result_list[1]).to eq("15:1")
        expect(result_list[2]).to eq("5:5")
      end

      it "does not find positive items when searching for negative items" do
        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 17, objects: "ABCD")

        expect(result_list.length).to eq(0)
      end
    end

    context "edge cases" do
      let(:map_data) { Array.new(17) { Array.new(17, 0) } }

      it "returns empty list when no items match" do
        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 17, objects: "ABCD")

        expect(result_list.length).to eq(0)
      end

      it "handles search at map boundary (top-left corner)" do
        map_data[0][0] = "A"  # A at (0, 0)
        map_data[1][1] = "B"  # B at (1, 1)

        koshien.locate_objects(result: result_list, cent: "0:0", sq_size: 5, objects: "ABCD")

        expect(result_list.length).to eq(2)
        expect(result_list[1]).to eq("0:0")
        expect(result_list[2]).to eq("1:1")
      end

      it "handles search at map boundary (bottom-right corner)" do
        map_data[16][16] = "A"  # A at (16, 16)
        map_data[15][15] = "B"  # B at (15, 15)

        koshien.locate_objects(result: result_list, cent: "16:16", sq_size: 5, objects: "ABCD")

        expect(result_list.length).to eq(2)
        expect(result_list[1]).to eq("15:15")
        expect(result_list[2]).to eq("16:16")
      end

      it "handles very small search area (size 1)" do
        map_data[8][8] = "A"  # A at (8, 8)

        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 1, objects: "ABCD")

        # Size 1, half_size = 0, so only the center cell
        expect(result_list.length).to eq(1)
        expect(result_list[1]).to eq("8:8")
      end

      it "handles large search area covering entire map" do
        map_data[0][0] = "A"
        map_data[16][16] = "B"

        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 99, objects: "ABCD")

        expect(result_list.length).to eq(2)
      end
    end

    context "sorting behavior" do
      let(:map_data) do
        Array.new(17) { Array.new(17, 0) }.tap do |map|
          # Add items in random order to test sorting
          map[5][10] = "A"  # (10, 5)
          map[5][2] = "B"   # (2, 5)
          map[3][8] = "C"   # (8, 3)
          map[3][4] = "A"   # (4, 3)
        end
      end

      it "returns items sorted by y coordinate, then x coordinate" do
        koshien.locate_objects(result: result_list, cent: "8:8", sq_size: 17, objects: "ABCD")

        expect(result_list.length).to eq(4)
        # Should be sorted: (4,3), (8,3), (2,5), (10,5)
        expect(result_list[1]).to eq("4:3")
        expect(result_list[2]).to eq("8:3")
        expect(result_list[3]).to eq("2:5")
        expect(result_list[4]).to eq("10:5")
      end
    end
  end
end
