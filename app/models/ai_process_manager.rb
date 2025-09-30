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

    Rails.logger.info "AI Process starting: script=#{@ai_script_path}, cmd=#{cmd}, env=#{env.inspect}"

    @stdin, @stdout, @stderr, @thread = Open3.popen3(env, cmd)
    @process_pid = @thread.pid
    @status = :starting
    @last_output_time = Time.now

    # Start a thread to monitor stderr
    @stderr_thread = Thread.new do
      while (line = @stderr.gets)
        Rails.logger.warn "AI STDERR [PID=#{@process_pid}]: #{line.chomp}"
      end
    rescue => e
      Rails.logger.debug "AI STDERR thread ended: #{e.message}"
    end

    Rails.logger.info "AI Process started: PID=#{@process_pid}, status=#{@status}"
    true
  rescue => e
    Rails.logger.error "Failed to start AI process: #{e.message}\n#{e.backtrace.join("\n")}"
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

    Rails.logger.info "AI Process [PID=#{@process_pid}] sending initialize message..."
    send_message(init_message)

    # Wait for ready response
    Rails.logger.info "AI Process [PID=#{@process_pid}] waiting for ready message..."
    response = wait_for_message
    Rails.logger.info "AI Process [PID=#{@process_pid}] received response: type=#{response&.dig("type")}, player_name=#{response&.dig("data", "player_name")}"

    if response && response["type"] == "ready"
      @player_name = response.dig("data", "player_name")
      @status = :ready
      Rails.logger.info "AI Process [PID=#{@process_pid}] initialized successfully: player_name=#{@player_name}, status=#{@status}"
      true
    else
      Rails.logger.error "AI Process [PID=#{@process_pid}] failed to respond with ready message, got: #{response.inspect}"
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

    Rails.logger.info "AI Process [PID=#{@process_pid}] sending turn_start: turn_number=#{turn_number}, player_position=#{current_player[:position]}"
    send_message(turn_message)
    @status = :turn_active
    Rails.logger.info "AI Process [PID=#{@process_pid}] status changed to :turn_active"
    true
  end

  # Wait for turn_over message from AI process
  def wait_for_turn_completion
    raise "No active turn" unless @status == :turn_active

    Rails.logger.info "AI Process [PID=#{@process_pid}] waiting for turn completion..."
    message_count = 0

    while @status == :turn_active
      message = wait_for_message
      message_count += 1

      Rails.logger.info "AI Process [PID=#{@process_pid}] received message ##{message_count}: type=#{message&.dig("type")}"

      case message&.dig("type")
      when "turn_over"
        actions = message.dig("data", "actions") || []
        @status = :turn_completed
        Rails.logger.info "AI Process [PID=#{@process_pid}] turn completed: actions=#{actions.length}, status=#{@status}"
        return {success: true, actions: actions}
      when "debug"
        Rails.logger.debug "AI Debug [PID=#{@process_pid}]: #{message.dig("data", "message")}"
        # Continue waiting for turn_over
      when "map_area_request"
        # Handle map area request from AI
        x = message.dig("data", "x")
        y = message.dig("data", "y")
        area_size = message.dig("data", "area_size") || 5
        Rails.logger.info "AI Process [PID=#{@process_pid}] map_area_request: x=#{x}, y=#{y}, area_size=#{area_size}"

        map_area_data = get_map_area_data(x, y, area_size)

        # Send response back to AI
        response = {
          type: "map_area_response",
          timestamp: Time.now.utc.iso8601,
          data: map_area_data
        }
        Rails.logger.info "AI Process [PID=#{@process_pid}] sending map_area_response"
        send_message(response)
        # Continue waiting for turn_over
      when "error"
        Rails.logger.error "AI Error [PID=#{@process_pid}]: #{message.dig("data", "message")}"
        # Continue waiting for turn_over
      when nil
        # Timeout or process ended
        @status = :timeout
        Rails.logger.error "AI Process [PID=#{@process_pid}] timeout or ended: status=#{@status}, alive=#{alive?}"
        return {success: false, reason: :timeout}
      else
        Rails.logger.warn "AI Process [PID=#{@process_pid}] unexpected message type: #{message["type"]}"
        # Continue waiting
      end
    end

    Rails.logger.warn "AI Process [PID=#{@process_pid}] exited wait loop with status: #{@status}"
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

    Rails.logger.info "AI Process [PID=#{@process_pid}] sending turn_end_confirm: turn=#{@turn_count}, actions=#{actions_processed}, next_turn=#{@turn_count < MAX_TURN}"
    send_message(confirm_message)
    @status = (@turn_count >= MAX_TURN) ? :game_completed : :ready
    Rails.logger.info "AI Process [PID=#{@process_pid}] status changed to: #{@status}"
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

    # Find game_round and player using instance variables
    game = Game.find(@game_id)
    game_round = game.game_rounds.find_by(round_number: @round_number)
    return {} unless game_round

    player = game_round.players.find_by(player_ai_id: @player_ai_id)
    return {} unless player

    game_map = game_round.game.game_map
    map_data = game_map.map_data
    items_data = game_map.items_data || Array.new(map_data.size) { Array.new(map_data.first.size, 0) }

    map_width = map_data.first.size
    map_height = map_data.size
    half_size = area_size / 2

    # Calculate range with boundary checks
    rng_x = if x < half_size
      (0..(x + half_size))
    elsif x > map_width - half_size - 1
      ((x - half_size)..(map_width - 1))
    else
      ((x - half_size)..(x + half_size))
    end

    rng_y = if y < half_size
      (0..(y + half_size))
    elsif y > map_height - half_size - 1
      ((y - half_size)..(map_height - 1))
    else
      ((y - half_size)..(y + half_size))
    end

    # Create snapshot: start with map data
    map_snapshot = []
    map_data[rng_y].each do |row|
      map_snapshot << row[rng_x].dup
    end

    # Overlay items from items_data (ITEM_MARKS mapping)
    items_data[rng_y].each_with_index do |row, y_pos|
      row[rng_x].each_with_index do |item_idx, x_pos|
        if item_idx.to_i != 0  # Not ITEM_BLANK_INDEX
          # Map item indices to marks (4-9 for items 1-6)
          map_snapshot[y_pos][x_pos] = item_idx + 3 if item_idx.between?(1, 6)
        end
      end
    end

    # Update player's personal map with this snapshot
    player.update_my_map(rng_x, rng_y, map_snapshot)
    player.save!

    # Check for other player in range
    other_players = game_round.players.where.not(id: player.id)
    other_player_pos = nil
    other_players.each do |other|
      if rng_x.include?(other.position_x) && rng_y.include?(other.position_y)
        other_player_pos = [other.position_x, other.position_y]
        break
      end
    end

    result = {
      map: map_snapshot,
      center_x: x,
      center_y: y,
      start_x: rng_x.first,
      start_y: rng_y.first,
      end_x: rng_x.last,
      end_y: rng_y.last,
      other_player: other_player_pos,
      enemies: []  # TODO: implement enemy detection in range
    }
    Rails.logger.debug "DEBUG: returning result: #{result.inspect}"
    result
  end
end
