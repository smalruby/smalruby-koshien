require "fileutils"

class GameEngine
  include GameConstants

  attr_reader :game, :current_round

  def initialize(game)
    @game = game
    @current_round = nil
  end

  def execute_battle
    Rails.logger.info "Executing battle for game #{game.id}"

    begin
      # Execute both rounds
      round_results = []

      (1..N_ROUNDS).each do |round_number|
        Rails.logger.info "Starting round #{round_number} for game #{game.id}"

        round_result = execute_round(round_number)
        round_results << round_result

        break unless round_result[:success]
      end

      # Determine overall winner based on round results
      winner = determine_overall_winner(round_results)

      {
        success: true,
        winner: winner,
        round_results: round_results
      }
    rescue => e
      Rails.logger.error "Game engine error: #{e.message}"
      {
        success: false,
        error: e.message
      }
    ensure
      # Clean up temporary files
      cleanup_temp_files
    end
  end

  private

  def execute_round(round_number)
    @current_round = initialize_round(round_number)

    begin
      # Execute turns until round is finished
      (1..MAX_TURN).each do |turn_number|
        Rails.logger.debug "Executing turn #{turn_number} for round #{round_number}"

        turn_result = execute_turn(turn_number)

        # Check if round should end early
        break if round_finished?(turn_result)
      end

      # Finalize round
      finalize_round

      {
        success: true,
        round_number: round_number,
        winner: determine_round_winner,
        final_scores: get_final_scores
      }
    rescue => e
      Rails.logger.error "Round #{round_number} error: #{e.message}"
      @current_round.update!(status: :finished)

      {
        success: false,
        round_number: round_number,
        error: e.message
      }
    end
  end

  def initialize_round(round_number)
    # Create new round
    round = game.game_rounds.create!(
      round_number: round_number,
      status: :preparing,
      item_locations: generate_item_locations
    )

    # Initialize players
    initialize_players(round)

    # Initialize enemies
    initialize_enemies(round)

    # Set round status to in_progress
    round.update!(status: :in_progress)

    round
  end

  def initialize_players(round)
    game_map = game.game_map
    start_positions = find_start_positions(game_map)

    [game.first_player_ai, game.second_player_ai].each_with_index do |player_ai, index|
      position = start_positions[index]

      round.players.create!(
        player_ai: player_ai,
        position_x: position[:x],
        position_y: position[:y],
        previous_position_x: position[:x],
        previous_position_y: position[:y],
        score: 0,
        character_level: 1,
        dynamite_left: N_DYNAMITE,
        bomb_left: N_BOMB,
        walk_bonus_counter: 0,
        acquired_positive_items: [0, 0, 0, 0, 0, 0],
        status: :playing
      )
    end
  end

  def initialize_enemies(round)
    game_map = game.game_map
    enemy_positions = find_enemy_positions(game_map)

    enemy_positions.each do |position|
      round.enemies.create!(
        position_x: position[:x],
        position_y: position[:y],
        previous_position_x: position[:x],
        previous_position_y: position[:y],
        state: :normal_state,
        enemy_kill: :no_kill
      )
    end
  end

  def execute_turn(turn_number)
    # Create turn record
    turn = @current_round.game_turns.create!(
      turn_number: turn_number,
      turn_finished: false
    )

    begin
      # Execute AI for each player
      players = @current_round.players.active_players.includes(:player_ai)
      ai_results = execute_player_ais(players, turn)

      # Process movements and actions
      process_turn_actions(players, ai_results, turn)

      # Update enemy states
      update_enemies(turn)

      # Check win conditions
      win_result = check_win_conditions(turn)

      # Mark turn as finished
      turn.update!(turn_finished: true)

      {
        turn_number: turn_number,
        ai_results: ai_results,
        win_result: win_result
      }
    rescue => e
      Rails.logger.error "Turn #{turn_number} error: #{e.message}"
      turn.update!(turn_finished: true)
      raise e
    end
  end

  def execute_player_ais(players, turn)
    # Execute AIs using process-based execution
    execute_ais_with_process_manager(players, turn)
  end

  # Process-based AI execution model using AiProcessManager
  def execute_ais_with_process_manager(players, turn)
    ai_results = []

    players.each_with_index do |player, player_index|
      Rails.logger.debug "Starting AI process execution for player #{player.id} (#{player_index})"

      begin
        # Get AI script path from player_ai
        ai_script_path = get_ai_script_path(player)

        # Create AI process manager
        ai_manager = AiProcessManager.new(
          ai_script_path: ai_script_path,
          game_id: @current_round.game.id.to_s,
          round_number: @current_round.round_number,
          player_index: player_index,
          player_ai_id: player.player_ai.id.to_s
        )

        # Start AI process
        unless ai_manager.start
          raise "Failed to start AI process for player #{player.id}"
        end

        # Initialize game with current state
        game_state = build_game_state_for_process(player)
        unless ai_manager.initialize_game(**game_state)
          raise "Failed to initialize AI game for player #{player.id}"
        end

        # Start turn
        turn_data = build_turn_data(player)
        unless ai_manager.start_turn(**turn_data)
          raise "Failed to start AI turn for player #{player.id}"
        end

        # Wait for turn completion
        Rails.logger.debug "Starting wait_for_turn_completion for player #{player.id} at #{Time.current}"
        turn_start_time = Time.current
        result = ai_manager.wait_for_turn_completion
        turn_elapsed_time = Time.current - turn_start_time

        Rails.logger.debug "Turn completion result for player #{player.id}: success=#{result[:success]}, elapsed=#{turn_elapsed_time.round(3)}s, reason=#{result[:reason]}"

        if result[:success]
          # Confirm turn end
          ai_manager.confirm_turn_end(actions_processed: result[:actions].length)

          ai_results << {
            player_id: player.id,
            success: true,
            result: {actions: result[:actions]}
          }
        else
          # Mark player as timeout
          player.update!(status: :timeout)

          ai_results << {
            player_id: player.id,
            success: false,
            error: "AI process failed: #{result[:reason]} (elapsed: #{turn_elapsed_time.round(3)}s)"
          }
        end

        # Stop AI process
        ai_manager.stop

        Rails.logger.debug "AI process execution completed for player #{player.id}"
      rescue => e
        Rails.logger.error "AI process execution failed for player #{player.id}: #{e.class} - #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"

        # Ensure AI process is stopped even on error
        ai_manager&.stop

        # Mark player as timeout
        player.update!(status: :timeout)

        ai_results << {
          player_id: player.id,
          success: false,
          error: e.message
        }
      end
    end

    ai_results
  end

  def process_turn_actions(players, ai_results, turn)
    turn_processor = TurnProcessor.new(@current_round, turn)
    turn_processor.process_actions(players, ai_results)
  end

  def update_enemies(turn)
    # Enemy AI logic - move enemies based on player positions
    @current_round.enemies.each do |enemy|
      next if enemy.killed?

      # Get current round players for enemy movement logic
      players = @current_round.players.reload

      # Execute enemy movement
      enemy.move(game.game_map.map_data, players)
      enemy.save!

      Rails.logger.debug "Enemy moved to (#{enemy.position_x}, #{enemy.position_y})"
    end
  end

  def check_win_conditions(turn)
    players = @current_round.players.reload

    # Check if any player reached goal
    goal_players = players.select { |p| reached_goal?(p) }
    return {type: :goal_reached, players: goal_players} if goal_players.any?

    # Check if all players finished/timeout
    active_players = players.select(&:playing?)
    return {type: :all_finished} if active_players.empty?

    # Check if max turns reached
    return {type: :max_turns} if turn.turn_number >= MAX_TURN

    {type: :continue}
  end

  def round_finished?(turn_result)
    win_result = turn_result[:win_result]
    win_result[:type] != :continue
  end

  def finalize_round
    @current_round.update!(status: :finished)

    # Apply final bonuses and calculate scores
    @current_round.players.each do |player|
      player.update_character_level
      apply_final_bonuses(player)
    end
  end

  def determine_round_winner
    players = @current_round.players.order(:score).reverse
    return :draw if players[0].score == players[1].score

    winner_player = players.first
    (game.first_player_ai == winner_player.player_ai) ? :player1 : :player2
  end

  def determine_overall_winner(round_results)
    return nil unless round_results.all? { |r| r[:success] }

    winners = round_results.map { |r| r[:winner] }

    # Count wins for each player
    player1_wins = winners.count(:player1)
    player2_wins = winners.count(:player2)

    return :first if player1_wins > player2_wins
    return :second if player2_wins > player1_wins

    # If tied, determine by total score across rounds
    determine_winner_by_total_score
  end

  def determine_winner_by_total_score
    # Calculate total scores across all rounds
    total_scores = {first: 0, second: 0}

    game.game_rounds.each do |round|
      players = round.players.includes(:player_ai)

      players.each do |player|
        if game.first_player_ai == player.player_ai
          total_scores[:first] += player.score
        else
          total_scores[:second] += player.score
        end
      end
    end

    return :first if total_scores[:first] > total_scores[:second]
    return :second if total_scores[:second] > total_scores[:first]
    nil # Draw
  end

  def get_final_scores
    @current_round.players.pluck(:score)
  end

  def find_start_positions(game_map)
    # Find valid starting positions by scanning the map for empty spaces
    map_data = game_map.map_data
    valid_positions = []

    # Scan the map for empty spaces (MAP_BLANK = 0)
    map_data.each_with_index do |row, y|
      row.each_with_index do |cell, x|
        if cell == MAP_BLANK  # Empty space
          valid_positions << {x: x, y: y}
        end
      end
    end

    # Return first two valid positions, or fallback positions if not enough found
    if valid_positions.length >= 2
      [valid_positions[0], valid_positions[1]]
    elsif valid_positions.length == 1
      [valid_positions[0], {x: 1, y: 1}]  # Fallback for second player
    else
      # Emergency fallback - use positions that are most likely to be valid
      [{x: 1, y: 1}, {x: 2, y: 2}]
    end
  end

  def find_enemy_positions(game_map)
    # TODO: Parse map data to find enemy positions
    # For now, return empty array
    []
  end

  def reached_goal?(player)
    game_map = game.game_map
    goal_pos = game_map.goal_position

    player.position_x == goal_pos["x"] && player.position_y == goal_pos["y"]
  end

  def build_game_state(player)
    # Build game state object for AI (legacy method for backward compatibility)
    {
      player: player.api_info,
      enemies: @current_round.enemies.map(&:api_info),
      map: game.game_map.map_data,
      items: @current_round.item_locations,
      turn: @current_round.game_turns.count + 1,
      round: @current_round.round_number,
      goal: game.game_map.goal_position
    }
  end

  def build_game_state_for_process(player)
    # Build game state for AiProcessManager initialization
    map_size = game.game_map.size
    {
      game_map: {
        width: map_size[:width],
        height: map_size[:height],
        map_data: game.game_map.map_data,
        goal_position: game.game_map.goal_position
      },
      initial_position: {x: player.position_x, y: player.position_y},
      initial_items: {
        dynamite_left: player.dynamite_left,
        bomb_left: player.bomb_left
      },
      game_constants: {
        max_turns: MAX_TURN,
        turn_timeout: TURN_DURATION
      },
      rand_seed: generate_rand_seed
    }
  end

  def build_turn_data(player)
    # Build turn data for AiProcessManager turn execution
    api_info = player.api_info
    Rails.logger.debug "DEBUG build_turn_data: player.api_info = #{api_info.inspect}"

    turn_data = {
      turn_number: @current_round.game_turns.count + 1,
      current_player: api_info,
      other_players: @current_round.players.where.not(id: player.id).map(&:api_info),
      enemies: @current_round.enemies.map(&:api_info),
      visible_map: build_visible_map(player)
    }

    Rails.logger.debug "DEBUG build_turn_data: turn_data = #{turn_data.inspect}"
    turn_data
  end

  def build_visible_map(player)
    # Build visible map based on player's exploration
    # For now, return the full map - TODO: implement exploration-based visibility
    map_size = game.game_map.size
    {
      width: map_size[:width],
      height: map_size[:height],
      map_data: game.game_map.map_data
    }
  end

  def get_ai_script_path(player)
    # Get AI script path from player's AI code
    # For now, write code to temp file - TODO: implement proper script management
    temp_dir = Rails.root.join("tmp", "ai_scripts")
    FileUtils.mkdir_p(temp_dir)

    # Use unique timestamp-based filename to prevent conflicts and enable cleanup
    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    script_path = temp_dir.join("player_#{player.id}_#{timestamp}_ai.rb")
    File.write(script_path, player.player_ai.code)

    # Store script path for cleanup
    @temp_script_paths ||= []
    @temp_script_paths << script_path.to_s

    script_path.to_s
  end

  def generate_rand_seed
    # Generate random seed for reproducible AI execution
    @rand_seed ||= Random.new_seed
  end

  def apply_final_bonuses(player)
    # Apply goal bonus if player reached goal
    if reached_goal?(player)
      player.apply_goal_bonus
      player.save!
    end
  end

  def generate_item_locations
    # TODO: Generate random item locations based on ITEM_QUANTITIES
    # For now, return empty hash
    {}
  end

  def cleanup_temp_files
    return unless @temp_script_paths

    @temp_script_paths.each do |script_path|
      File.delete(script_path) if File.exist?(script_path)
      Rails.logger.debug "Cleaned up temp file: #{script_path}"
    rescue => e
      Rails.logger.warn "Failed to clean up temp file #{script_path}: #{e.message}"
    end

    @temp_script_paths.clear
  end
end
