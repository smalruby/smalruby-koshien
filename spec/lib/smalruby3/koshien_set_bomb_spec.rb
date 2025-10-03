require "rails_helper"

RSpec.describe "Smalruby3::Koshien#set_bomb", type: :model do
  let(:koshien) { Smalruby3::Koshien.instance }

  before do
    # Reset koshien state
    koshien.instance_variable_set(:@current_turn_data, {})
    koshien.instance_variable_set(:@actions, [])
    koshien.instance_variable_set(:@mode, :json)
    koshien.instance_variable_set(:@current_position, nil)
  end

  describe "in JSON mode" do
    before do
      allow(koshien).to receive(:in_test_env?).and_return(false)
      allow(koshien).to receive(:in_json_mode?).and_return(true)
    end
    it "adds set_bomb action with position" do
      koshien.set_bomb("5:3")

      actions = koshien.instance_variable_get(:@actions)
      expect(actions.length).to eq(1)
      expect(actions.first[:action_type]).to eq("set_bomb")
      expect(actions.first[:target_x]).to eq(5)
      expect(actions.first[:target_y]).to eq(3)
    end

    it "uses current position when no argument provided" do
      koshien.instance_variable_set(:@current_turn_data, {"current_player" => {"x" => 7, "y" => 9}})

      koshien.set_bomb

      actions = koshien.instance_variable_get(:@actions)
      expect(actions.length).to eq(1)
      expect(actions.first[:action_type]).to eq("set_bomb")
      expect(actions.first[:target_x]).to eq(7)
      expect(actions.first[:target_y]).to eq(9)
    end

    it "handles string coordinates with colon separator" do
      koshien.set_bomb("10:15")

      actions = koshien.instance_variable_get(:@actions)
      expect(actions.first[:target_x]).to eq(10)
      expect(actions.first[:target_y]).to eq(15)
    end
  end

  describe "in test mode" do
    before do
      koshien.instance_variable_set(:@mode, :test)
      allow(koshien).to receive(:in_test_env?).and_return(true)
      allow(koshien).to receive(:in_json_mode?).and_return(false)
    end

    it "logs bomb placement without adding actions" do
      expect(koshien).to receive(:log).with("Set bomb at: 3:4")

      koshien.set_bomb("3:4")

      actions = koshien.instance_variable_get(:@actions)
      expect(actions).to be_empty
    end
  end
end
