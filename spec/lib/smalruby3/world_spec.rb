# frozen_string_literal: true

require "rails_helper"

RSpec.describe Smalruby3::World do
  let(:world) { described_class.instance }

  # Create mock objects for stage and sprite
  let(:mock_stage) do
    double("Stage", stage?: true, name: "test_stage")
  end

  let(:mock_sprite) do
    double("Sprite", stage?: false, name: "test_sprite")
  end

  let(:another_sprite) do
    double("Sprite", stage?: false, name: "another_sprite")
  end

  before do
    # Reset world state before each test
    world.reset
  end

  describe "#initialize" do
    it "calls reset on initialization" do
      # Singleton already initialized, so we verify reset behavior
      expect(world.stage).to be_nil
      expect(world.sprites).to eq([])
    end
  end

  describe "#reset" do
    it "clears all sprites and stage" do
      world.add_target(mock_sprite)
      world.add_target(mock_stage)

      world.reset

      expect(world.stage).to be_nil
      expect(world.sprites).to eq([])
    end
  end

  describe "#add_target" do
    context "when adding a stage" do
      it "sets the stage" do
        result = world.add_target(mock_stage)

        expect(world.stage).to eq(mock_stage)
        expect(result).to eq(mock_stage)
      end

      it "raises ExistStage error when stage already exists" do
        world.add_target(mock_stage)

        another_stage = double("Stage", stage?: true, name: "another_stage")

        expect {
          world.add_target(another_stage)
        }.to raise_error(Smalruby3::ExistStage)
      end
    end

    context "when adding a sprite" do
      it "adds sprite to sprites array" do
        result = world.add_target(mock_sprite)

        expect(world.sprites).to include(mock_sprite)
        expect(result).to eq(mock_sprite)
      end

      it "allows multiple sprites with different names" do
        world.add_target(mock_sprite)
        world.add_target(another_sprite)

        expect(world.sprites.length).to eq(2)
        expect(world.sprites).to include(mock_sprite)
        expect(world.sprites).to include(another_sprite)
      end

      it "raises ExistSprite error when sprite with same name already exists" do
        world.add_target(mock_sprite)

        duplicate_sprite = double("Sprite", stage?: false, name: "test_sprite")

        expect {
          world.add_target(duplicate_sprite)
        }.to raise_error(Smalruby3::ExistSprite)
      end
    end
  end

  describe "singleton behavior" do
    it "returns same instance" do
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1).to eq(instance2)
    end
  end
end
