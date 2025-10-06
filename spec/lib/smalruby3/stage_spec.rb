# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::Stage do
  let(:stage) { described_class.new("test_stage") }

  before do
    # Reset world state before each test
    Smalruby3::World.instance.reset
  end

  describe "#stage?" do
    it "returns true" do
      expect(stage.stage?).to be true
    end
  end

  describe "inheritance" do
    it "inherits from Sprite" do
      expect(described_class.superclass).to eq(Smalruby3::Sprite)
    end
  end

  describe "#define_variable (private)" do
    it "defines a global variable with $ prefix" do
      # Use send to call private method
      variable_name = stage.send(:define_variable, "test_var", 42)

      expect(variable_name).to eq("$test_var")
      expect(eval(variable_name)).to eq(42) # rubocop:disable Security/Eval
    end

    it "sets the global variable value" do
      stage.send(:define_variable, "my_value", "hello")

      expect($my_value).to eq("hello") # rubocop:disable Style/GlobalVars
    end

    it "returns the variable name with $ prefix" do
      result = stage.send(:define_variable, "foo", 123)

      expect(result).to start_with("$")
      expect(result).to eq("$foo")
    end
  end
end
