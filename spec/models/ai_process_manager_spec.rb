# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiProcessManager, type: :model do
  let(:ai_script_path) { Rails.root.join("spec", "fixtures", "player_ai", "stage_02_wait_only.rb") }
  let(:game_id) { "123" }
  let(:round_number) { 1 }
  let(:player_index) { 0 }
  let(:player_ai_id) { "456" }

  let(:manager) do
    AiProcessManager.new(
      ai_script_path: ai_script_path,
      game_id: game_id,
      round_number: round_number,
      player_index: player_index,
      player_ai_id: player_ai_id
    )
  end

  let(:game_map) do
    {
      width: 15,
      height: 15,
      map_data: Array.new(15) { Array.new(15, 0) },
      goal_position: {x: 14, y: 14}
    }
  end

  let(:initial_position) { {x: 0, y: 0} }
  let(:initial_items) { {dynamite_left: 2, bomb_left: 2} }
  let(:game_constants) { {max_turns: 50, turn_timeout: 5} }
  let(:rand_seed) { 12345 }

  let(:current_player) do
    {
      id: "789",
      position: {x: 0, y: 0},
      previous_position: {x: 0, y: 0},
      score: 0,
      character_level: 1,
      dynamite_left: 2,
      bomb_left: 2,
      walk_bonus_counter: 0,
      acquired_positive_items: [0, 0, 0, 0, 0, 0],
      status: "playing"
    }
  end

  let(:visible_map) do
    {
      width: 15,
      height: 15,
      map_data: Array.new(15) { Array.new(15, 0) }
    }
  end

  describe "#initialize" do
    it "sets initial attributes correctly" do
      expect(manager.game_id).to eq(game_id)
      expect(manager.round_number).to eq(round_number)
      expect(manager.player_index).to eq(player_index)
      expect(manager.player_ai_id).to eq(player_ai_id)
      expect(manager.status).to eq(:not_started)
    end
  end

  describe "#start" do
    context "with valid AI script" do
      it "starts the process successfully" do
        expect(manager.start).to be true
        expect(manager.status).to eq(:starting)
        expect(manager.process_pid).to be_a(Integer)
        expect(manager.alive?).to be true

        manager.stop
      end
    end

    context "with invalid AI script path" do
      let(:ai_script_path) { "/nonexistent/script.rb" }

      it "fails to start the process" do
        expect(manager.start).to be false
        expect(manager.status).to eq(:failed)
        expect(manager.process_pid).to be_nil
      end
    end

    context "when already started" do
      before { manager.start }
      after { manager.stop }

      it "raises an error" do
        expect { manager.start }.to raise_error("Process already started")
      end
    end
  end

  describe "#initialize_game" do
    before { manager.start }
    after { manager.stop }

    it "sends initialization message and receives ready response" do
      expect(manager.initialize_game(
        game_map: game_map,
        initial_position: initial_position,
        initial_items: initial_items,
        game_constants: game_constants,
        rand_seed: rand_seed
      )).to be true

      expect(manager.status).to eq(:ready)
      expect(manager.player_name).to eq("wait_only_player")
    end

    context "when process not started" do
      let(:manager) do
        AiProcessManager.new(
          ai_script_path: ai_script_path,
          game_id: game_id,
          round_number: round_number,
          player_index: player_index,
          player_ai_id: player_ai_id
        )
      end

      it "raises an error" do
        expect {
          manager.initialize_game(
            game_map: game_map,
            initial_position: initial_position,
            initial_items: initial_items,
            game_constants: game_constants,
            rand_seed: rand_seed
          )
        }.to raise_error("Process not started")
      end
    end
  end

  describe "#start_turn and #wait_for_turn_completion" do
    before do
      manager.start
      manager.initialize_game(
        game_map: game_map,
        initial_position: initial_position,
        initial_items: initial_items,
        game_constants: game_constants,
        rand_seed: rand_seed
      )
    end

    after { manager.stop }

    it "processes a complete turn cycle" do
      # Start turn
      expect(manager.start_turn(
        turn_number: 1,
        current_player: current_player,
        other_players: [],
        enemies: [],
        visible_map: visible_map
      )).to be true

      expect(manager.status).to eq(:turn_active)

      # Wait for turn completion
      result = manager.wait_for_turn_completion
      expect(result[:success]).to be true
      expect(result[:actions]).to be_an(Array)
      expect(manager.status).to eq(:turn_completed)

      # Confirm turn end
      expect(manager.confirm_turn_end(actions_processed: result[:actions].length)).to be true
      expect(manager.status).to eq(:ready)
    end
  end

  describe "#end_game" do
    before do
      manager.start
      manager.initialize_game(
        game_map: game_map,
        initial_position: initial_position,
        initial_items: initial_items,
        game_constants: game_constants,
        rand_seed: rand_seed
      )
    end

    after { manager.stop }

    it "sends game end message and stops process" do
      expect(manager.alive?).to be true

      manager.end_game(
        reason: "max_turns_reached",
        final_score: 100,
        final_position: {x: 5, y: 5},
        round_winner: "player_1",
        total_turns: 50
      )

      expect(manager.status).to eq(:stopped)
      expect(manager.alive?).to be false
    end
  end

  describe "#stop" do
    before { manager.start }

    it "stops the process cleanly" do
      expect(manager.alive?).to be true

      manager.stop

      expect(manager.alive?).to be false
      expect(manager.status).to eq(:stopped)
      expect(manager.process_pid).to be_nil
    end
  end

  describe "#timed_out?" do
    before do
      manager.start
      manager.initialize_game(
        game_map: game_map,
        initial_position: initial_position,
        initial_items: initial_items,
        game_constants: game_constants,
        rand_seed: rand_seed
      )
    end

    after { manager.stop }

    it "returns false when process is responsive" do
      expect(manager.timed_out?).to be false
    end

    # Note: Testing actual timeout requires waiting 5+ seconds
    # which would slow down tests significantly
  end

  describe "process lifecycle with timeout AI" do
    let(:timeout_ai_script) { Rails.root.join("spec", "fixtures", "player_ai", "stage_01_timeout.rb") }
    let(:timeout_manager) do
      AiProcessManager.new(
        ai_script_path: timeout_ai_script,
        game_id: game_id,
        round_number: round_number,
        player_index: player_index,
        player_ai_id: player_ai_id
      )
    end

    it "handles timeout scenarios" do
      timeout_manager.start
      expect(timeout_manager.initialize_game(
        game_map: game_map,
        initial_position: initial_position,
        initial_items: initial_items,
        game_constants: game_constants,
        rand_seed: rand_seed
      )).to be true

      timeout_manager.start_turn(
        turn_number: 1,
        current_player: current_player,
        other_players: [],
        enemies: [],
        visible_map: visible_map
      )

      # AI will timeout (doesn't call turn_over)
      result = timeout_manager.wait_for_turn_completion
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:timeout)

      timeout_manager.stop
    end
  end

  describe "JSON protocol compliance" do
    before do
      manager.start
      manager.initialize_game(
        game_map: game_map,
        initial_position: initial_position,
        initial_items: initial_items,
        game_constants: game_constants,
        rand_seed: rand_seed
      )
    end

    after { manager.stop }

    it "follows the JSON protocol specification" do
      # Test message structure
      manager.start_turn(
        turn_number: 1,
        current_player: current_player,
        other_players: [],
        enemies: [],
        visible_map: visible_map
      )

      result = manager.wait_for_turn_completion
      expect(result).to have_key(:success)
      expect(result).to have_key(:actions) if result[:success]
      expect(result).to have_key(:reason) unless result[:success]

      if result[:success]
        actions = result[:actions]
        expect(actions).to be_an(Array)
        expect(actions.length).to be <= 2  # Max 2 actions per turn

        actions.each do |action|
          expect(action).to have_key("action_type")
          expect(["move", "use_item", "explore"]).to include(action["action_type"])
        end
      end
    end
  end
end
