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
        hp: 100,
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
        hp: 100,
        attack_power: 10,
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
    ai_engine = AiEngine.new

    players.map do |player|
      # Execute player AI code
      ai_result = ai_engine.execute_ai(
        player: player,
        game_state: build_game_state(player),
        turn: turn
      )

      {
        player_id: player.id,
        success: true,
        result: ai_result
      }
    rescue => e
      Rails.logger.error "AI execution failed for player #{player.id}: #{e.message}"

      # Mark player as timeout
      player.update!(status: :timeout)

      {
        player_id: player.id,
        success: false,
        error: e.message
      }
    end
  end

  def process_turn_actions(players, ai_results, turn)
    turn_processor = TurnProcessor.new(@current_round, turn)
    turn_processor.process_actions(players, ai_results)
  end

  def update_enemies(turn)
    # Enemy AI logic will be implemented here
    # For now, basic enemy behavior
    @current_round.enemies.each do |enemy|
      next unless enemy.alive?

      # Simple enemy movement logic
      # TODO: Implement proper enemy AI
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
    # TODO: Parse map data to find start positions
    # For now, return default positions that avoid walls
    [
      {x: 0, y: 0},
      {x: 2, y: 2}
    ]
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
    # Build game state object for AI
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
end
