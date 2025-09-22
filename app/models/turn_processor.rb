class TurnProcessor
  include GameConstants

  attr_reader :game_round, :game_turn

  def initialize(game_round, game_turn)
    @game_round = game_round
    @game_turn = game_turn
  end

  def process_actions(players, ai_results)
    Rails.logger.debug "Processing turn #{game_turn.turn_number} actions"

    # Process each player's actions
    players.each_with_index do |player, index|
      ai_result = ai_results[index]

      if ai_result[:success] && ai_result[:result]
        process_player_actions(player, ai_result[:result])
      else
        # Player failed to provide valid action, mark as timeout
        player.update!(status: :timeout)
        create_game_event(player, "AI_TIMEOUT", {error: ai_result[:error]})
      end
    end

    # Process collisions and interactions
    process_collisions
    process_item_interactions
    process_enemy_interactions

    # Update scores and bonuses
    update_player_scores
  end

  private

  def process_player_actions(player, ai_result)
    return unless player.playing?

    # Extract actions from AI result
    actions = extract_actions(ai_result)

    actions.each do |action|
      case action[:type]
      when "move"
        process_movement(player, action[:direction])
      when "use_item"
        process_item_usage(player, action[:item])
      when "wait"
        # Player chooses to wait, no action needed
        create_game_event(player, "WAIT")
      else
        Rails.logger.warn "Unknown action type: #{action[:type]}"
      end
    end
  end

  def extract_actions(ai_result)
    if ai_result[:actions]
      ai_result[:actions]
    elsif ai_result[:action]
      [ai_result[:action]]
    else
      [{type: "wait"}]
    end
  end

  def process_movement(player, direction)
    old_x, old_y = player.position_x, player.position_y
    new_x, new_y = calculate_new_position(old_x, old_y, direction)

    # Check if movement is valid
    if valid_movement?(new_x, new_y)
      # Update player position
      player.move_to(new_x, new_y)
      player.save!

      create_game_event(player, "MOVE", {
        from: {x: old_x, y: old_y},
        to: {x: new_x, y: new_y},
        direction: direction
      })

      Rails.logger.debug "Player #{player.id} moved from (#{old_x},#{old_y}) to (#{new_x},#{new_y})"
    else
      # Movement blocked
      create_game_event(player, "MOVE_BLOCKED", {
        attempted: {x: new_x, y: new_y},
        direction: direction
      })

      Rails.logger.debug "Player #{player.id} movement blocked to (#{new_x},#{new_y})"
    end
  end

  def calculate_new_position(x, y, direction)
    case direction
    when "up"
      [x, y - 1]
    when "down"
      [x, y + 1]
    when "left"
      [x - 1, y]
    when "right"
      [x + 1, y]
    else
      [x, y]
    end
  end

  def valid_movement?(x, y)
    # Check bounds
    map_data = game_round.game.game_map.map_data
    return false if x < 0 || y < 0 || y >= map_data.length || x >= map_data[0].length

    # Check map obstacles
    cell_value = map_data[y][x]

    case cell_value
    when MAP_BLANK, MAP_GOAL
      true
    when MAP_WALL1, MAP_WALL2, MAP_WATER
      false
    when MAP_BREAKABLE_WALL
      # Breakable walls can be moved through if destroyed
      true
    else
      true
    end
  end

  def process_item_usage(player, item_type)
    case item_type
    when "dynamite"
      use_dynamite(player)
    when "bomb"
      use_bomb(player)
    else
      Rails.logger.warn "Unknown item type: #{item_type}"
    end
  end

  def use_dynamite(player)
    if player.can_use_dynamite?
      player.use_dynamite
      player.save!

      # Create explosion effect
      create_explosion(player.position_x, player.position_y, :dynamite)

      create_game_event(player, "USE_DYNAMITE", {
        position: {x: player.position_x, y: player.position_y},
        remaining: player.dynamite_left
      })

      Rails.logger.debug "Player #{player.id} used dynamite at (#{player.position_x},#{player.position_y})"
    else
      create_game_event(player, "USE_DYNAMITE_FAILED", {
        reason: "no_dynamite_left"
      })
    end
  end

  def use_bomb(player)
    if player.can_use_bomb?
      player.use_bomb
      player.save!

      # Create explosion effect
      create_explosion(player.position_x, player.position_y, :bomb)

      create_game_event(player, "USE_BOMB", {
        position: {x: player.position_x, y: player.position_y},
        remaining: player.bomb_left
      })

      Rails.logger.debug "Player #{player.id} used bomb at (#{player.position_x},#{player.position_y})"
    else
      create_game_event(player, "USE_BOMB_FAILED", {
        reason: "no_bomb_left"
      })
    end
  end

  def create_explosion(x, y, type)
    # TODO: Implement explosion logic
    # - Destroy breakable walls
    # - Damage enemies in range
    # - Affect other players in range

    Rails.logger.debug "Explosion created at (#{x},#{y}) type: #{type}"
  end

  def process_collisions
    # Check player-player collisions
    players = game_round.players.where(status: :playing)

    players.each do |player1|
      players.each do |player2|
        next if player1.id >= player2.id

        if players_collided?(player1, player2)
          handle_player_collision(player1, player2)
        end
      end
    end
  end

  def players_collided?(player1, player2)
    player1.position_x == player2.position_x &&
      player1.position_y == player2.position_y
  end

  def handle_player_collision(player1, player2)
    # Handle collision logic - for now just log it
    create_game_event(nil, "PLAYER_COLLISION", {
      player1_id: player1.id,
      player2_id: player2.id,
      position: {x: player1.position_x, y: player1.position_y}
    })

    Rails.logger.debug "Players #{player1.id} and #{player2.id} collided at (#{player1.position_x},#{player1.position_y})"
  end

  def process_item_interactions
    players = game_round.players.where(status: :playing)

    players.each do |player|
      # Check if player is on an item location
      item_at_position = game_round.item_locations.dig(player.position_y.to_s, player.position_x.to_s)

      if item_at_position && item_at_position != ITEM_BLANK_INDEX
        collect_item(player, item_at_position)
      end
    end
  end

  def collect_item(player, item_index)
    # Add item to player's inventory
    if item_index.between?(1, 5)
      player.get_positive_item(item_index)
      score_bonus = ITEM_SCORES[item_index]
      player.score += score_bonus
      player.save!

      # Remove item from map
      remove_item_from_map(player.position_x, player.position_y)

      create_game_event(player, "COLLECT_ITEM", {
        item_index: item_index,
        score_bonus: score_bonus,
        position: {x: player.position_x, y: player.position_y}
      })

      Rails.logger.debug "Player #{player.id} collected item #{item_index} for #{score_bonus} points"
    end
  end

  def remove_item_from_map(x, y)
    # Update item_locations to remove the collected item
    current_items = game_round.item_locations.dup
    current_items[y.to_s] ||= {}
    current_items[y.to_s][x.to_s] = ITEM_BLANK_INDEX

    game_round.update!(item_locations: current_items)
  end

  def process_enemy_interactions
    enemies = game_round.enemies
    players = game_round.players.where(status: :playing)

    enemies.each do |enemy|
      next unless enemy.alive?

      players.each do |player|
        if enemy_player_interaction?(enemy, player)
          handle_enemy_player_interaction(enemy, player)
        end
      end
    end
  end

  def enemy_player_interaction?(enemy, player)
    # Check if enemy and player are in the same position or adjacent
    distance = (enemy.position_x - player.position_x).abs + (enemy.position_y - player.position_y).abs
    distance <= 1
  end

  def handle_enemy_player_interaction(enemy, player)
    # Determine player index (0 for first player, 1 for second player)
    player_index = if player.player_ai == game_round.game.first_player_ai
      0
    else
      1
    end

    # Enemy attacks player
    if enemy.can_attack?(player_index)
      damage = enemy.attack_power
      player.hp = [player.hp - damage, 0].max
      player.score = [player.score + ENEMY_DISCOUNT, 0].max

      if player.hp <= 0
        player.status = :completed
      end

      player.save!

      create_game_event(player, "ENEMY_ATTACK", {
        enemy_id: enemy.id,
        damage: damage,
        remaining_hp: player.hp,
        position: {x: player.position_x, y: player.position_y}
      })

      Rails.logger.debug "Enemy #{enemy.id} attacked player #{player.id} for #{damage} damage"
    end
  end

  def update_player_scores
    players = game_round.players.where(status: :playing)

    players.each do |player|
      # Apply walk bonus if player moved
      if player.has_moved?
        if player.calc_walk_bonus_with_counter
          create_game_event(player, "WALK_BONUS", {
            bonus: WALK_BONUS,
            total_score: player.score
          })
        end
      end

      # Update character level based on score
      player.update_character_level
      player.save!
    end
  end

  def create_game_event(player, event_type, data = {})
    game_turn.game_events.create!(
      player: player,
      event_type: event_type,
      event_data: data,
      occurred_at: Time.current
    )
  end
end
