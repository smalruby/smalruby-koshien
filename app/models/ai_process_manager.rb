# frozen_string_literal: true

require "json"
require "open3"
require "timeout"

# AI Process Execution Wrapper
# Manages Ruby AI process execution with JSON communication over stdin/stdout
class AiProcessManager
  include GameConstants

  TIMEOUT_SECONDS = TURN_DURATION  # Use game constants timeout

  attr_reader :process_pid, :stdin, :stdout, :stderr, :thread, :player_name,
    :game_id, :round_number, :player_index, :player_ai_id

  def initialize(ai_script_path:, game_id:, round_number:, player_index:, player_ai_id:)
    @ai_script_path = ai_script_path
    @game_id = game_id
    @round_number = round_number
    @player_index = player_index
    @player_ai_id = player_ai_id
    @process_pid = nil
    @stdin = nil
    @stdout = nil
    @stderr = nil
    @thread = nil
    @player_name = nil
    @status = :not_started
    @turn_count = 0
    @last_output_time = nil
  end

  # Start AI process and initialize communication
  def start
    raise "Process already started" if @status != :not_started

    cmd = if smalruby3?(@ai_script_path)
      lib_dir = Rails.root.join("lib").to_s
      "ruby -I #{lib_dir} #{@ai_script_path}"
    else
      "ruby #{@ai_script_path}"
    end

    # Set environment variables for JSON communication
    env = {
      "KOSHIEN_JSON_MODE" => "true",
      "RAILS_ENV" => Rails.env
    }

    @stdin, @stdout, @stderr, @thread = Open3.popen3(env, cmd)
    @process_pid = @thread.pid
    @status = :starting
    @last_output_time = Time.now

    Rails.logger.info "AI Process started: PID=#{@process_pid}, script=#{@ai_script_path}, cmd=#{cmd}"
    true
  rescue => e
    Rails.logger.error "Failed to start AI process: #{e.message}"
    @status = :failed
    false
  end

  # Send initialization message to AI process
  def initialize_game(game_map:, initial_position:, initial_items:, game_constants:, rand_seed:)
    raise "Process not started" unless @status == :starting

    init_message = {
      type: "initialize",
      timestamp: Time.now.utc.iso8601,
      data: {
        game_id: @game_id,
        round_number: @round_number,
        player_index: @player_index,
        player_ai_id: @player_ai_id,
        rand_seed: rand_seed,
        game_map: game_map,
        initial_position: initial_position,
        initial_items: initial_items,
        game_constants: game_constants
      }
    }

    send_message(init_message)

    # Wait for ready response
    Rails.logger.debug "AI Process waiting for ready message..."
    response = wait_for_message
    Rails.logger.debug "AI Process received response: #{response.inspect}"

    if response && response["type"] == "ready"
      @player_name = response.dig("data", "player_name")
      @status = :ready
      Rails.logger.info "AI Process initialized: #{@player_name}"
      true
    else
      Rails.logger.error "AI Process failed to respond with ready message, got: #{response.inspect}"
      @status = :failed
      false
    end
  end

  # Start a new turn by sending turn_start message
  def start_turn(turn_number:, current_player:, other_players:, enemies:, visible_map:)
    raise "Process not ready" unless @status == :ready

    @turn_count = turn_number

    turn_message = {
      type: "turn_start",
      timestamp: Time.now.utc.iso8601,
      data: {
        turn_number: turn_number,
        current_player: current_player,
        other_players: other_players,
        enemies: enemies,
        visible_map: visible_map
      }
    }

    Rails.logger.debug "DEBUG AiProcessManager start_turn: sending message with current_player=#{current_player.inspect}"
    send_message(turn_message)
    @status = :turn_active
    true
  end

  # Wait for turn_over message from AI process
  def wait_for_turn_completion
    raise "No active turn" unless @status == :turn_active

    while @status == :turn_active
      message = wait_for_message

      case message&.dig("type")
      when "turn_over"
        actions = message.dig("data", "actions") || []
        @status = :turn_completed
        return {success: true, actions: actions}
      when "debug"
        Rails.logger.debug "AI Debug: #{message.dig("data", "message")}"
        # Continue waiting for turn_over
      when "map_area_request"
        # Handle map area request from AI
        Rails.logger.debug "DEBUG: Received map_area_request: #{message.inspect}"
        x = message.dig("data", "x")
        y = message.dig("data", "y")
        area_size = message.dig("data", "area_size") || 5
        Rails.logger.debug "DEBUG: Processing map area request for x=#{x}, y=#{y}, area_size=#{area_size}"

        map_area_data = get_map_area_data(x, y, area_size)
        Rails.logger.debug "DEBUG: Generated map area data: #{map_area_data.inspect}"

        # Send response back to AI
        response = {
          type: "map_area_response",
          timestamp: Time.now.utc.iso8601,
          data: map_area_data
        }
        Rails.logger.debug "DEBUG: Sending map_area_response: #{response.inspect}"
        send_message(response)
        Rails.logger.debug "DEBUG: map_area_response sent, continuing to wait for turn_over"
        # Continue waiting for turn_over
      when "error"
        Rails.logger.error "AI Error: #{message.dig("data", "message")}"
        # Continue waiting for turn_over
      when nil
        # Timeout or process ended
        @status = :timeout
        return {success: false, reason: :timeout}
      else
        Rails.logger.warn "Unexpected message type: #{message["type"]}"
        # Continue waiting
      end
    end

    {success: false, reason: :unknown}
  end

  # Send turn end confirmation
  def confirm_turn_end(actions_processed:)
    raise "Turn not completed" unless @status == :turn_completed

    confirm_message = {
      type: "turn_end_confirm",
      timestamp: Time.now.utc.iso8601,
      data: {
        turn_number: @turn_count,
        actions_processed: actions_processed,
        next_turn_will_start: @turn_count < MAX_TURN
      }
    }

    send_message(confirm_message)
    @status = (@turn_count >= MAX_TURN) ? :game_completed : :ready
    true
  end

  # Send game end message and stop process
  def end_game(reason:, final_score: 0, final_position: nil, round_winner: nil, total_turns: 0)
    return unless alive?

    end_message = {
      type: "game_end",
      timestamp: Time.now.utc.iso8601,
      data: {
        reason: reason,
        final_score: final_score,
        final_position: final_position,
        round_winner: round_winner,
        total_turns: total_turns
      }
    }

    send_message(end_message)
    @status = :game_ended
    stop
  end

  # Stop the AI process
  def stop
    return unless alive?

    Rails.logger.debug "Stopping AI process PID=#{@process_pid}"

    begin
      # Close stdin first to signal the process
      @stdin&.close

      # Wait for process to terminate gracefully
      if @thread&.alive?
        @thread.join(1) # Wait 1 second
        if @thread.alive?
          # Force kill if still alive
          begin
            Process.kill("TERM", @process_pid)
            @thread.join(1)
            if @thread.alive?
              Process.kill("KILL", @process_pid)
              Rails.logger.warn "AI Process force killed: PID=#{@process_pid}"
            else
              Rails.logger.info "AI Process terminated: PID=#{@process_pid}"
            end
          rescue Errno::ESRCH
            # Process already died, this is fine
            Rails.logger.debug "AI Process already terminated: PID=#{@process_pid}"
          end
        else
          Rails.logger.info "AI Process terminated gracefully: PID=#{@process_pid}"
        end
      end

      # Close remaining streams
      @stdout&.close
      @stderr&.close
    rescue => e
      Rails.logger.error "Error stopping AI process: #{e.message}"
    ensure
      @status = :stopped
      @process_pid = nil
      @stdin = nil
      @stdout = nil
      @stderr = nil
      @thread = nil
    end
  end

  # Check if process is alive and responsive
  def alive?
    @thread&.alive? == true && @status != :stopped
  end

  # Check if process timed out
  def timed_out?
    return false unless @last_output_time

    Time.now - @last_output_time > TIMEOUT_SECONDS
  end

  # Get current status
  def status
    if alive? && timed_out?
      @status = :timeout
      stop
    end
    @status
  end

  private

  # Check if AI script uses smalruby3
  def smalruby3?(ai_path)
    File.open(ai_path) do |f|
      while (line = f.gets)
        return true if /require.*smalruby3/.match?(line)
        return false if /require.*["']smalruby["']/.match?(line)
      end
    end
    false
  end

  # Send JSON message to AI process stdin
  def send_message(message)
    raise "Process not available" unless alive?

    json_message = message.to_json + "\n"
    @stdin.write(json_message)
    @stdin.flush
    Rails.logger.debug "Sent to AI: #{json_message.chomp}"
  rescue => e
    Rails.logger.error "Failed to send message to AI process: #{e.message}"
    @status = :failed
  end

  # Wait for JSON message from AI process stdout with timeout
  def wait_for_message
    return nil unless alive?

    # Debug: log the timeout value being used
    Rails.logger.debug "AI Process wait_for_message: using timeout=#{TIMEOUT_SECONDS} seconds, current time=#{Time.current}"

    begin
      timeout_start = Time.current
      Timeout.timeout(TIMEOUT_SECONDS) do
        line = @stdout.readline
        timeout_elapsed = Time.current - timeout_start
        @last_output_time = Time.now

        message = JSON.parse(line.chomp)
        Rails.logger.debug "Received from AI (after #{timeout_elapsed.round(3)}s): #{line.chomp}"
        message
      end
    rescue Timeout::Error
      timeout_elapsed = Time.current - timeout_start
      Rails.logger.warn "AI Process timeout: no output for #{TIMEOUT_SECONDS} seconds (actual elapsed: #{timeout_elapsed.round(3)}s)"
      @status = :timeout
      nil
    rescue EOFError
      timeout_elapsed = Time.current - timeout_start
      Rails.logger.info "AI Process ended (EOF) after #{timeout_elapsed.round(3)}s"
      @status = :ended
      nil
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON from AI process: #{e.message}"
      # Continue waiting for valid JSON
      retry if alive?
      nil
    rescue => e
      Rails.logger.error "Error reading from AI process: #{e.message}"
      @status = :failed
      nil
    end
  end

  private

  # Get map area data for the specified coordinates
  # Based on the original smalruby-koshien implementation
  def get_map_area_data(x, y, area_size = 5)
    Rails.logger.debug "DEBUG: get_map_area_data called with x=#{x}, y=#{y}, area_size=#{area_size}"

    # This is a simplified implementation that returns mock data
    # In a full implementation, this would access the actual game state
    # and return real map data based on the current game round

    # For now, return mock data structure matching the expected format
    half_size = area_size / 2
    Rails.logger.debug "DEBUG: half_size=#{half_size}"

    # Calculate the area bounds (5x5 around the target position)
    start_x = [0, x - half_size].max
    end_x = [16, x + half_size].min  # Assuming 17x17 map
    start_y = [0, y - half_size].max
    end_y = [16, y + half_size].min
    Rails.logger.debug "DEBUG: bounds: start_x=#{start_x}, end_x=#{end_x}, start_y=#{start_y}, end_y=#{end_y}"

    # Mock map data - in real implementation this would come from GameMap
    map_area = []
    (start_y..end_y).each do |map_y|
      row = []
      (start_x..end_x).each do |map_x|
        # 0 = empty space, 2 = wall - mock data for now
        cell_value = (map_x == 0 || map_x == 16 || map_y == 0 || map_y == 16) ? 2 : 0
        row << cell_value
      end
      map_area << row
    end
    Rails.logger.debug "DEBUG: generated map_area: #{map_area.inspect}"

    result = {
      map: map_area,
      center_x: x,
      center_y: y,
      start_x: start_x,
      start_y: start_y,
      end_x: end_x,
      end_y: end_y,
      other_player: nil,  # Would be calculated based on other player position
      enemies: []  # Would be calculated based on enemy positions
    }
    Rails.logger.debug "DEBUG: returning result: #{result.inspect}"
    result
  end
end
