# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::IgnoreMethodMissing do
  let(:instance) { described_class.new }

  describe "#method_missing" do
    it "returns a new instance of the class" do
      result = instance.some_undefined_method

      expect(result).to be_a(described_class)
      expect(result).not_to eq(instance)
    end

    it "handles method calls with arguments" do
      result = instance.another_method(1, 2, 3)

      expect(result).to be_a(described_class)
    end

    it "warns about the missing method" do
      expect { instance.missing_method }.to output(/no method error/).to_stderr
    end
  end

  describe "#respond_to_missing?" do
    it "delegates to super" do
      # respond_to_missing? should return false for non-existent methods
      # when delegating to super (default Object behavior)
      expect(instance.respond_to?(:some_nonexistent_method, true)).to be false
    end
  end
end
