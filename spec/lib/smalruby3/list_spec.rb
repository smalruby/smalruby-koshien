# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::List do
  describe "#initialize" do
    it "creates empty list by default" do
      list = described_class.new

      expect(list.length).to eq(0)
    end

    it "creates list from array" do
      list = described_class.new([1, 2, 3])

      expect(list.length).to eq(3)
      expect(list[1]).to eq(1)
      expect(list[2]).to eq(2)
      expect(list[3]).to eq(3)
    end
  end

  describe "#push" do
    it "adds element to the end of list" do
      list = described_class.new([1, 2])
      list.push(3)

      expect(list.length).to eq(3)
      expect(list[3]).to eq(3)
    end
  end

  describe "#delete_at" do
    it "deletes element at list index (1-based)" do
      list = described_class.new([10, 20, 30])
      list.delete_at(2)

      expect(list.length).to eq(2)
      expect(list[1]).to eq(10)
      expect(list[2]).to eq(30)
    end

    it "supports negative indices" do
      list = described_class.new([10, 20, 30])
      list.delete_at(-1)

      expect(list.length).to eq(2)
      expect(list[1]).to eq(10)
      expect(list[2]).to eq(20)
    end
  end

  describe "#clear" do
    it "removes all elements from list" do
      list = described_class.new([1, 2, 3])
      list.clear

      expect(list.length).to eq(0)
    end
  end

  describe "#[]=" do
    it "sets element at list index (1-based)" do
      list = described_class.new([10, 20, 30])
      list[2] = 99

      expect(list[2]).to eq(99)
    end

    it "supports negative indices" do
      list = described_class.new([10, 20, 30])
      list[-1] = 99

      expect(list[-1]).to eq(99)
    end
  end

  describe "#insert" do
    it "inserts element at list index (1-based)" do
      list = described_class.new([10, 30])
      list.insert(2, 20)

      expect(list.length).to eq(3)
      expect(list[1]).to eq(10)
      expect(list[2]).to eq(20)
      expect(list[3]).to eq(30)
    end
  end

  describe "#[]" do
    it "gets element at list index (1-based)" do
      list = described_class.new([10, 20, 30])

      expect(list[1]).to eq(10)
      expect(list[2]).to eq(20)
      expect(list[3]).to eq(30)
    end

    it "supports negative indices" do
      list = described_class.new([10, 20, 30])

      expect(list[-1]).to eq(30)
      expect(list[-2]).to eq(20)
    end
  end

  describe "#index" do
    it "finds list index (1-based) of element" do
      list = described_class.new(%w[apple banana cherry])

      expect(list.index("apple")).to eq(1)
      expect(list.index("banana")).to eq(2)
      expect(list.index("cherry")).to eq(3)
    end
  end

  describe "#length" do
    it "returns number of elements" do
      list = described_class.new([1, 2, 3, 4, 5])

      expect(list.length).to eq(5)
    end
  end

  describe "#include?" do
    it "checks if element exists in list" do
      list = described_class.new(%w[red green blue])

      expect(list.include?("red")).to be true
      expect(list.include?("green")).to be true
      expect(list.include?("yellow")).to be false
    end
  end

  describe "#replace" do
    it "replaces list contents with new array" do
      list = described_class.new([1, 2, 3])
      list.replace([10, 20, 30, 40])

      expect(list.length).to eq(4)
      expect(list[1]).to eq(10)
      expect(list[4]).to eq(40)
    end
  end

  describe "#map" do
    it "transforms each element with block" do
      list = described_class.new([1, 2, 3])
      result = list.map { |x| x * 2 }

      expect(result).to eq([2, 4, 6])
    end
  end

  describe "#each" do
    it "iterates over each element" do
      list = described_class.new([1, 2, 3])
      result = []
      list.each { |x| result << x * 2 }

      expect(result).to eq([2, 4, 6])
    end
  end

  describe "#to_s" do
    it "converts list to string" do
      list = described_class.new([1, 2, 3])

      expect(list.to_s).to eq("123")
    end

    it "joins elements without separator" do
      list = described_class.new(%w[hello world])

      expect(list.to_s).to eq("helloworld")
    end
  end

  describe "#to_array_index (private)" do
    context "with 0 index" do
      it "raises ArgumentError" do
        list = described_class.new([10, 20, 30])

        expect { list[0] }.to raise_error(ArgumentError, "リストの何番目には1以上の整数、または-1以下の整数を指定してください")
      end
    end

    context "with positive index" do
      it "converts 1-based to 0-based" do
        list = described_class.new([10, 20, 30])

        # List index 1 -> Array index 0 -> value 10
        expect(list[1]).to eq(10)
      end
    end

    context "with negative index" do
      it "keeps negative index as-is" do
        list = described_class.new([10, 20, 30])

        # List index -1 -> Array index -1 -> value 30
        expect(list[-1]).to eq(30)
      end
    end
  end

  describe "#to_list_index (private)" do
    context "with non-negative array index" do
      it "converts 0-based to 1-based" do
        list = described_class.new(%w[a b c])

        # Array index 0 returns "a", so list index should be 1
        expect(list.index("a")).to eq(1)
      end
    end
  end
end
