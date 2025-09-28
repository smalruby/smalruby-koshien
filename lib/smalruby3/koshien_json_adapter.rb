# frozen_string_literal: true

require "json"
require "time"

module Smalruby3
  # JSON Protocol Adapter for Koshien AI execution
  # This module extends the Koshien singleton to support JSON communication
  class KoshienJsonAdapter
    include Singleton

    def initialize
      @actions = []
      @game_state = nil
      @player_name = nil
      @initialized = false
      @current_position = {x: 0, y: 0}  # Track position locally as fallback
    end

    # Setup JSON communication with AiProcessManager
    def setup_json_communication
      @initialized = true

      # Debug output
      warn "DEBUG setup_json_communication: instance=#{object_id}, @player_name=#{@player_name.inspect}"

      # Wait for initialization message from AiProcessManager first
      warn "DEBUG: Waiting for initialize message from AiProcessManager..."
      message = read_message
      warn "DEBUG: Received message: #{message.inspect}"

      if message && message["type"] == "initialize"
        @game_state = message["data"]
        @rand_seed = @game_state["rand_seed"]
        srand(@rand_seed) if @rand_seed

        # Initialize position from initial_position if available
        if @game_state["initial_position"]
          @current_position = {
            x: @game_state["initial_position"]["x"],
            y: @game_state["initial_position"]["y"]
          }
          warn "DEBUG: Initialized @current_position from game state: #{@current_position.inspect}"
        end

        # Store initialization success but don't send ready message yet
        # Ready message will be sent when connect_game is called
        @initialization_received = true
        warn "DEBUG: Initialization received, waiting for connect_game"
        true
      else
        warn "DEBUG: setup_json_communication failed - unexpected message type or nil"
        false
      end
    end

    # Main game loop - wait for turns and execute
    def run_game_loop
      loop do
        message = read_message
        break unless message

        case message["type"]
        when "turn_start"
          handle_turn_start(message["data"])
        when "turn_end_confirm"
          handle_turn_end_confirm(message["data"])
        when "game_end"
          handle_game_end(message["data"])
          break
        else
          send_error_message("Unknown message type: #{message["type"]}")
        end
      end
    end

    # Action collection methods (called by koshien library methods)
    def add_action(action)
      @actions << action
    end

    def clear_actions
      @actions.clear
    end

    def get_actions
      @actions.dup
    end

    # Game state accessors
    def current_player_position
      # First try to get position from current turn data
      if @current_turn_data && @current_turn_data["current_player"]
        current_player = @current_turn_data["current_player"]
        warn "DEBUG current_player_position: using turn data current_player=#{current_player.inspect}"

        # Handle both possible data structures
        if current_player["position"]
          result = current_player["position"]
          warn "DEBUG current_player_position: using position=#{result.inspect}"
          return result
        elsif current_player["x"] && current_player["y"]
          result = {x: current_player["x"], y: current_player["y"]}
          warn "DEBUG current_player_position: using x/y=#{result.inspect}"
          return result
        end
      end

      # Fallback to locally tracked position
      warn "DEBUG current_player_position: using fallback @current_position=#{@current_position.inspect}"
      @current_position
    end

    def other_players
      @current_turn_data&.dig("other_players") || []
    end

    def enemies
      @current_turn_data&.dig("enemies") || []
    end

    def visible_map
      @current_turn_data&.dig("visible_map") || {}
    end

    def goal_position
      @game_state&.dig("game_map", "goal_position") || {x: 14, y: 14}
    end

    private

    def extract_player_name_from_script
      # Use stored player name if available, otherwise extract from script filename
      @player_name || (
        if $0 && File.basename($0).match?(/stage_\d+_(.+)\.rb/)
          File.basename($0, ".rb").gsub(/^stage_\d+_/, "")
        else
          "json_ai_player"
        end
      )
    end

    def send_ready_message(player_name)
      # Use the stored player name from connect_game if available
      final_player_name = @player_name || player_name
      @player_name = final_player_name

      # Debug output
      warn "DEBUG: @player_name=#{@player_name.inspect}, player_name=#{player_name.inspect}, final=#{final_player_name.inspect}"

      send_message({
        type: "ready",
        timestamp: Time.now.utc.iso8601,
        data: {
          player_name: final_player_name,
          ai_version: "1.0.0",
          status: "initialized"
        }
      })
    end

    def handle_turn_start(data)
      @current_turn_data = data
      @current_turn = data["turn_number"]

      # Debug: log turn data structure
      warn "DEBUG handle_turn_start: turn_data=#{data.inspect}"
      if data["current_player"]
        warn "DEBUG current_player: #{data["current_player"].inspect}"

        # Update local position tracking when we receive turn data
        current_player = data["current_player"]
        if current_player && current_player["x"] && current_player["y"]
          @current_position = {x: current_player["x"], y: current_player["y"]}
          warn "DEBUG handle_turn_start: updated @current_position to #{@current_position.inspect}"
        end
      end

      # Clear previous actions
      clear_actions

      # Allow the AI script to execute (this will be caught by koshien.turn_over)
      yield if block_given?
    end

    def handle_turn_end_confirm(data)
      send_debug_message("Turn #{data["turn_number"]} confirmed, #{data["actions_processed"]} actions processed")
    end

    def handle_game_end(data)
      send_debug_message("Game ended: #{data["reason"]}, final score: #{data.fetch("final_score", 0)}")
    end

    def send_message(message)
      $stdout.puts(message.to_json)
      $stdout.flush
    end

    def send_debug_message(message)
      send_message({
        type: "debug",
        timestamp: Time.now.utc.iso8601,
        data: {
          level: "info",
          message: message,
          context: {
            current_action: "debug",
            turn_number: @current_turn
          }
        }
      })
    end

    def send_error_message(error_message)
      send_message({
        type: "error",
        timestamp: Time.now.utc.iso8601,
        data: {
          error_type: "runtime_error",
          message: error_message,
          details: {}
        }
      })
    end

    public

    def send_turn_over
      actions = get_actions
      send_message({
        type: "turn_over",
        timestamp: Time.now.utc.iso8601,
        data: {
          actions: actions
        }
      })
      clear_actions
    end

    # Wait for turn processing to complete
    def wait_for_turn_completion
      loop do
        message = read_message
        return false unless message

        case message["type"]
        when "turn_end_confirm"
          handle_turn_end_confirm(message["data"])
          return true # Turn completed, continue to next turn
        when "game_end"
          handle_game_end(message["data"])
          exit(0) # Game finished, exit script
        when "turn_start"
          # New turn started, update state and return
          handle_turn_start(message["data"])
          return true
        else
          send_error_message("Unexpected message type during turn completion: #{message["type"]}")
          return false
        end
      end
    end

    # Update position when movements are planned (fallback position tracking)
    def track_movement_action(target_x, target_y)
      # Update the fallback position to track intended movements
      # This helps when turn data doesn't arrive properly
      @current_position = {x: target_x, y: target_y}
      warn "DEBUG track_movement_action: updated @current_position to #{@current_position.inspect}"
    end

    def read_message
      line = $stdin.gets
      return nil unless line

      JSON.parse(line.chomp)
    rescue JSON::ParserError => e
      send_error_message("Invalid JSON: #{e.message}")
      nil
    end
  end

  # Extend the original Koshien class to work with JSON communication
  class Koshien
    private

    def json_adapter
      # Always use the singleton instance, don't cache per Koshien instance
      adapter = KoshienJsonAdapter.instance
      warn "DEBUG json_adapter: #{adapter.object_id}, @player_name=#{adapter.instance_variable_get(:@player_name).inspect}"
      adapter
    end

    def in_json_mode?
      # JSON mode is now the default behavior
      # Only disable if explicitly set to false
      ENV["KOSHIEN_JSON_MODE"] != "false"
    end

    public

    # Override methods to work with JSON communication
    def connect_game(name:)
      if in_json_mode?
        # Store player name for JSON communication in both Koshien and KoshienJsonAdapter instances
        @player_name = name

        # Also store in KoshienJsonAdapter singleton to ensure it's preserved
        adapter = json_adapter
        adapter.instance_variable_set(:@player_name, name)

        log("Connected to game as: #{name}")

        # Debug output
        warn "DEBUG connect_game: instance=#{object_id}, set @player_name=#{@player_name.inspect}"
        warn "DEBUG connect_game: adapter instance=#{adapter.object_id}, set adapter @player_name=#{adapter.instance_variable_get(:@player_name).inspect}"

        # Send ready message now that we have the player name
        if adapter.instance_variable_get(:@initialization_received)
          adapter.send(:send_ready_message, name)
          warn "DEBUG connect_game: Sent ready message with player name: #{name}"
        else
          warn "DEBUG connect_game: Initialization not received yet, ready message will be sent later"
        end
      else
        # Original stub behavior
        log(%(プレイヤー名を設定します: name="#{name}"))
      end
    end

    def move_to(position)
      if in_json_mode?
        if position.is_a?(String) && position.include?(":")
          x, y = position.split(":").map(&:to_i)
          json_adapter.add_action({action_type: "move", target_x: x, target_y: y})
          # Track the intended movement for fallback position tracking
          json_adapter.track_movement_action(x, y)
        end
      else
        # Original stub behavior
        log("Move to: #{position}")
      end
    end

    def get_map_area(position)
      if in_json_mode?
        if position.is_a?(String) && position.include?(":")
          x, y = position.split(":").map(&:to_i)
          json_adapter.add_action({action_type: "explore", target_position: {x: x, y: y}, area_size: 5})
        end
      else
        # Original stub behavior
        log("Get map area: #{position}")
      end
    end

    def set_dynamite(position = nil)
      if in_json_mode?
        pos = position || player
        if pos.is_a?(String) && pos.include?(":")
          x, y = pos.split(":").map(&:to_i)
          json_adapter.add_action({action_type: "use_item", item: "dynamite", position: {x: x, y: y}})
        end
      else
        # Original stub behavior
        log("Set dynamite at: #{position}")
      end
    end

    def set_bomb(position = nil)
      if in_json_mode?
        pos = position || player
        if pos.is_a?(String) && pos.include?(":")
          x, y = pos.split(":").map(&:to_i)
          json_adapter.add_action({action_type: "use_item", item: "bomb", position: {x: x, y: y}})
        end
      else
        # Original stub behavior
        log("Set bomb at: #{position}")
      end
    end

    def turn_over
      if in_json_mode?
        json_adapter.send_turn_over
        # Wait for turn processing to complete before returning control to script
        json_adapter.wait_for_turn_completion
      else
        # Original stub behavior
        log("Turn over")
      end
    end

    def set_message(message)
      if in_json_mode?
        json_adapter.send_debug_message(message.to_s)
      else
        # Original stub behavior
        log("Message: #{message}")
      end
    end

    # Override position getters to use JSON data
    def player
      if in_json_mode?
        pos = json_adapter.current_player_position
        "#{pos[:x]}:#{pos[:y]}"
      else
        position(0, 0)
      end
    end

    def player_x
      if in_json_mode?
        json_adapter.current_player_position[:x]
      else
        0
      end
    end

    def player_y
      if in_json_mode?
        json_adapter.current_player_position[:y]
      else
        0
      end
    end

    def goal
      if in_json_mode?
        pos = json_adapter.goal_position
        "#{pos[:x]}:#{pos[:y]}"
      else
        "14:14"
      end
    end

    def goal_x
      if in_json_mode?
        json_adapter.goal_position[:x]
      else
        14
      end
    end

    def goal_y
      if in_json_mode?
        json_adapter.goal_position[:y]
      else
        14
      end
    end
  end
end
