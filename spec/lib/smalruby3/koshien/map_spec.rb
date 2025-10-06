# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::Koshien::Map do
  describe "#initialize" do
    context "with Array input" do
      it "creates map from array" do
        array_map = [
          [0, 1, 2],
          [3, 4, 5],
          [-1, 0, 1]
        ]
        map = described_class.new(array_map)

        expect(map.map).to eq(array_map)
      end
    end

    context "with String input" do
      it "creates map from string" do
        string_map = "012,345,-01"
        map = described_class.new(string_map)

        expect(map.map).to eq([
          [0, 1, 2],
          [3, 4, 5],
          [-1, 0, 1]
        ])
      end
    end
  end

  describe "#to_a" do
    it "returns map as array" do
      array_map = [
        [0, 1, 2],
        [3, 4, 5]
      ]
      map = described_class.new(array_map)

      expect(map.to_a).to eq(array_map)
    end
  end

  describe "#data" do
    let(:map_array) { [[0, 1, 2], [3, 4, 5], [-1, 0, 1]] }
    let(:map) { described_class.new(map_array) }

    it "returns cell value for valid position" do
      position = Smalruby3::Koshien::Position.new(1, 1)
      expect(map.data(position)).to eq(4)
    end

    it "returns -1 for position with negative x" do
      position = Smalruby3::Koshien::Position.new(-1, 1)
      expect(map.data(position)).to eq(-1)
    end

    it "returns -1 for position with negative y" do
      position = Smalruby3::Koshien::Position.new(1, -1)
      expect(map.data(position)).to eq(-1)
    end

    it "returns -1 for position beyond map bounds" do
      position = Smalruby3::Koshien::Position.new(10, 10)
      expect(map.data(position)).to eq(-1)
    end

    it "returns -1 when map is nil" do
      empty_map = described_class.new
      position = Smalruby3::Koshien::Position.new(0, 0)
      expect(empty_map.data(position)).to eq(-1)
    end
  end

  describe "#to_s" do
    it "converts map array to string format" do
      array_map = [[0, 1, 2], [3, 4, 5], [-1, 0, 1]]
      map = described_class.new(array_map)

      expect(map.to_s).to eq("012,345,-01")
    end
  end
end
