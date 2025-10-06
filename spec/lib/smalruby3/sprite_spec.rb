# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::Sprite do
  before do
    # Reset world state before each test
    Smalruby3::World.instance.reset
  end

  describe "#initialize" do
    it "creates sprite with name" do
      sprite = described_class.new("test_sprite")

      expect(sprite.name).to eq("test_sprite")
    end

    it "initializes with empty variables and lists" do
      sprite = described_class.new("test_sprite")

      expect(sprite.variables).to eq([])
      expect(sprite.lists).to eq([])
    end

    it "sets variables from options" do
      sprite = described_class.new("test_sprite", variables: [
        {name: "var1", value: 10},
        {name: "var2", value: 20}
      ])

      expect(sprite.variables).to eq(["@var1", "@var2"])
      expect(sprite.instance_variable_get(:@var1)).to eq(10)
      expect(sprite.instance_variable_get(:@var2)).to eq(20)
    end

    it "sets lists from options" do
      sprite = described_class.new("test_sprite", lists: [
        {name: "list1", value: [1, 2, 3]},
        {name: "list2", value: [4, 5]}
      ])

      expect(sprite.lists).to eq(["@list1", "@list2"])
      expect(sprite.instance_variable_get(:@list1)).to be_a(Smalruby3::List)
      expect(sprite.instance_variable_get(:@list2)).to be_a(Smalruby3::List)
    end

    it "executes block in instance context" do
      result = nil
      described_class.new("test_sprite") do
        result = name
      end

      expect(result).to eq("test_sprite")
    end

    it "adds sprite to World" do
      sprite = described_class.new("test_sprite")

      expect(Smalruby3::World.instance.sprites).to include(sprite)
    end
  end

  describe "#stage?" do
    it "returns false" do
      sprite = described_class.new("test_sprite")

      expect(sprite.stage?).to be false
    end
  end

  describe "#variables=" do
    it "defines variables with default value 0" do
      sprite = described_class.new("test_sprite")
      sprite.variables = [{name: "counter"}]

      expect(sprite.variables).to eq(["@counter"])
      expect(sprite.instance_variable_get(:@counter)).to eq(0)
    end

    it "defines variables with specified values" do
      sprite = described_class.new("test_sprite")
      sprite.variables = [
        {name: "x", value: 100},
        {name: "y", value: 200}
      ]

      expect(sprite.instance_variable_get(:@x)).to eq(100)
      expect(sprite.instance_variable_get(:@y)).to eq(200)
    end
  end

  describe "#lists=" do
    it "defines lists with default empty array" do
      sprite = described_class.new("test_sprite")
      sprite.lists = [{name: "items"}]

      expect(sprite.lists).to eq(["@items"])
      expect(sprite.instance_variable_get(:@items)).to be_a(Smalruby3::List)
      expect(sprite.instance_variable_get(:@items).length).to eq(0)
    end

    it "defines lists with specified values" do
      sprite = described_class.new("test_sprite")
      sprite.lists = [{name: "numbers", value: [10, 20, 30]}]

      list = sprite.instance_variable_get(:@numbers)
      expect(list).to be_a(Smalruby3::List)
      expect(list.length).to eq(3)
    end
  end

  describe "#list" do
    it "retrieves list by name" do
      sprite = described_class.new("test_sprite", lists: [
        {name: "my_list", value: [1, 2, 3]}
      ])

      list = sprite.list("@my_list")

      expect(list).to be_a(Smalruby3::List)
      expect(list.length).to eq(3)
    end
  end

  describe "#koshien" do
    it "returns Koshien singleton instance" do
      sprite = described_class.new("test_sprite")

      expect(sprite.koshien).to eq(Smalruby3::Koshien.instance)
    end
  end

  describe "#method_missing" do
    it "returns IgnoreMethodMissing instance" do
      sprite = described_class.new("test_sprite")
      result = sprite.some_undefined_method

      expect(result).to be_a(Smalruby3::IgnoreMethodMissing)
    end

    it "handles method calls with arguments" do
      sprite = described_class.new("test_sprite")
      result = sprite.another_method(1, 2, 3)

      expect(result).to be_a(Smalruby3::IgnoreMethodMissing)
    end

    it "warns about the missing method" do
      sprite = described_class.new("test_sprite")

      expect { sprite.missing_method(1, 2) }.to output(/no method error/).to_stderr
    end
  end

  describe "#respond_to_missing?" do
    it "delegates to super" do
      sprite = described_class.new("test_sprite")

      expect(sprite.respond_to?(:some_nonexistent_method, true)).to be false
    end
  end

  describe "#define_variable (private)" do
    it "defines instance variable with @ prefix" do
      sprite = described_class.new("test_sprite")
      variable_name = sprite.send(:define_variable, "test_var", 42)

      expect(variable_name).to eq("@test_var")
      expect(sprite.instance_variable_get(:@test_var)).to eq(42)
    end

    it "sets the instance variable value" do
      sprite = described_class.new("test_sprite")
      sprite.send(:define_variable, "my_value", "hello")

      expect(sprite.instance_variable_get(:@my_value)).to eq("hello")
    end

    it "returns the variable name with @ prefix" do
      sprite = described_class.new("test_sprite")
      result = sprite.send(:define_variable, "foo", 123)

      expect(result).to start_with("@")
      expect(result).to eq("@foo")
    end
  end
end
