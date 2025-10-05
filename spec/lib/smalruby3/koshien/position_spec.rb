# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::Koshien::Position do
  describe "#initialize" do
    context "with x and y coordinates as separate arguments" do
      it "creates position from x and y values" do
        position = described_class.new(3, 5)

        expect(position.x).to eq(3)
        expect(position.y).to eq(5)
      end
    end

    context "with Position instance" do
      it "creates position from another Position" do
        original = described_class.new(7, 9)
        copy = described_class.new(original)

        expect(copy.x).to eq(7)
        expect(copy.y).to eq(9)
      end
    end

    context "with String input" do
      it "creates position from 'x:y' string format" do
        position = described_class.new("4:8")

        expect(position.x).to eq(4)
        expect(position.y).to eq(8)
      end
    end

    context "with Array input" do
      it "creates position from [x, y] array" do
        position = described_class.new([2, 6])

        expect(position.x).to eq(2)
        expect(position.y).to eq(6)
      end
    end
  end

  describe "#to_s" do
    it "returns position in 'x:y' string format" do
      position = described_class.new(10, 15)

      expect(position.to_s).to eq("10:15")
    end
  end

  describe "#to_a" do
    it "returns position as [x, y] array" do
      position = described_class.new(12, 18)

      expect(position.to_a).to eq([12, 18])
    end
  end
end
