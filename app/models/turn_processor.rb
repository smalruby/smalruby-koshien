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

    # Process explosions (dynamites and bombs explode at end of turn)
    process_explosions

    # Update scores and bonuses
    update_player_scores
  end

  private

  def process_player_actions(player, ai_result)
    return unless player.playing?

    # Extract actions from AI result
    actions = extract_actions(ai_result)
    Rails.logger.info "🎮 Player #{player.id} (#{player.player_ai.name}) actions: #{actions.inspect}"

    actions.each do |action|
      Rails.logger.info "  ▶️ Processing action: type=#{action[:type]}, details=#{action.inspect}"
      case action[:type]
      when "move"
        if action[:direction]
          process_movement(player, action[:direction])
        elsif action[:target_x] && action[:target_y]
          process_move_to_target(player, action[:target_x], action[:target_y])
        end
      when "use_item"
        process_item_usage(player, action[:item])
      when "set_dynamite"
        process_set_dynamite(player, action[:target_x], action[:target_y])
      when "set_bomb"
        process_set_bomb(player, action[:target_x], action[:target_y])
      when "wait"
        # Player chooses to wait, no action needed
        create_game_event(player, "WAIT")
      when "explore"
        # Player is exploring map area, create exploration event
        create_game_event(player, "EXPLORE", {target: action[:target_position]})
      else
        Rails.logger.warn "Unknown action type: #{action[:type]}"
      end
    end
  end

  def extract_actions(ai_result)
    actions = if ai_result[:actions]
      ai_result[:actions]
    elsif ai_result[:action]
      [ai_result[:action]]
    else
      [{type: "wait"}]
    end

    # Normalize action format from JSON (string keys) to expected format (symbol keys)
    actions.map do |action|
      if action.is_a?(Hash)
        normalized = {}
        # Convert action_type to type
        normalized[:type] = action["action_type"] || action[:action_type] || action["type"] || action[:type]

        # Copy other relevant fields
        normalized[:direction] = action["direction"] || action[:direction]
        normalized[:target_x] = action["target_x"] || action[:target_x]
        normalized[:target_y] = action["target_y"] || action[:target_y]
        normalized[:item] = action["item"] || action[:item]
        normalized[:target] = action["target"] || action[:target]
        normalized[:target_position] = action["target_position"] || action[:target_position]
        normalized[:position] = action["position"] || action[:position]
        normalized[:area_size] = action["area_size"] || action[:area_size]

        normalized
      else
        action
      end
    end
  end

  def process_movement(player, direction)
    old_x, old_y = player.position_x, player.position_y
    new_x, new_y = calculate_new_position(old_x, old_y, direction)

    Rails.logger.info "  🚶 Movement: (#{old_x},#{old_y}) → (#{new_x},#{new_y}) via #{direction}"

    # Check if movement is valid
    if valid_movement?(new_x, new_y)
      # Update player position
      player.move_to(new_x, new_y)
      player.save!
      Rails.logger.info "  ✅ Movement successful"

      create_game_event(player, "MOVE", {
        from: {x: old_x, y: old_y},
        to: {x: new_x, y: new_y},
        direction: direction
      })

      Rails.logger.debug "Player #{player.id} moved from (#{old_x},#{old_y}) to (#{new_x},#{new_y})"
    else
      # Movement blocked
      Rails.logger.info "  ❌ Movement blocked to (#{new_x},#{new_y})"
      create_game_event(player, "MOVE_BLOCKED", {
        attempted: {x: new_x, y: new_y},
        direction: direction
      })
    end
  end

  def process_move_to_target(player, target_x, target_y)
    old_x, old_y = player.position_x, player.position_y

    Rails.logger.info "  🎯 process_move_to_target: from (#{old_x},#{old_y}) to target (#{target_x},#{target_y})"

    # Calculate direction to target (only allow one step movement)
    dx = target_x - old_x
    dy = target_y - old_y

    Rails.logger.info "  🎯 Delta: dx=#{dx}, dy=#{dy}"

    # Normalize to single step
    if dx.abs > dy.abs
      new_x = old_x + ((dx > 0) ? 1 : -1)
      new_y = old_y
      Rails.logger.info "  🎯 Moving in X direction: (#{old_x},#{old_y}) → (#{new_x},#{new_y})"
    elsif dy != 0
      new_x = old_x
      new_y = old_y + ((dy > 0) ? 1 : -1)
      Rails.logger.info "  🎯 Moving in Y direction: (#{old_x},#{old_y}) → (#{new_x},#{new_y})"
    else
      # Already at target
      new_x = old_x
      new_y = old_y
      Rails.logger.info "  🎯 Already at target"
    end

    # Check if movement is valid
    if valid_movement?(new_x, new_y)
      # Update player position
      player.move_to(new_x, new_y)
      player.save!

      create_game_event(player, "MOVE", {
        from: {x: old_x, y: old_y},
        to: {x: new_x, y: new_y},
        target: {x: target_x, y: target_y}
      })

      Rails.logger.debug "Player #{player.id} moved from (#{old_x},#{old_y}) to (#{new_x},#{new_y}) toward target (#{target_x},#{target_y})"
    else
      # Movement blocked
      create_game_event(player, "MOVE_BLOCKED", {
        attempted: {x: new_x, y: new_y},
        target: {x: target_x, y: target_y}
      })

      Rails.logger.debug "Player #{player.id} movement blocked from (#{old_x},#{old_y}) to (#{new_x},#{new_y})"
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

  def process_set_dynamite(player, target_x, target_y)
    # Check if player has dynamite left
    unless player.can_use_dynamite?
      create_game_event(player, "SET_DYNAMITE_FAILED", {
        reason: "no_dynamite_left",
        target: {x: target_x, y: target_y}
      })
      return
    end

    # Check if target position is valid for dynamite placement
    unless valid_dynamite_position?(player, target_x, target_y)
      create_game_event(player, "SET_DYNAMITE_FAILED", {
        reason: "invalid_position",
        target: {x: target_x, y: target_y}
      })
      return
    end

    # Place dynamite and consume one from player's inventory
    player.use_dynamite
    player.save!

    # Add dynamite to the round's dynamite tracking
    add_dynamite_to_round(target_x, target_y)

    create_game_event(player, "SET_DYNAMITE", {
      position: {x: target_x, y: target_y},
      remaining: player.dynamite_left
    })

    Rails.logger.debug "Player #{player.id} set dynamite at (#{target_x},#{target_y})"
  end

  def process_set_bomb(player, target_x, target_y)
    # Check if player has bomb left
    unless player.can_use_bomb?
      create_game_event(player, "SET_BOMB_FAILED", {
        reason: "no_bomb_left",
        target: {x: target_x, y: target_y}
      })
      return
    end

    # Check if target position is valid for bomb placement
    unless valid_bomb_position?(player, target_x, target_y)
      create_game_event(player, "SET_BOMB_FAILED", {
        reason: "invalid_position",
        target: {x: target_x, y: target_y}
      })
      return
    end

    # Place bomb and consume one from player's inventory
    player.use_bomb
    player.save!

    # Add bomb to the round's bomb tracking
    add_bomb_to_round(target_x, target_y)

    create_game_event(player, "SET_BOMB", {
      position: {x: target_x, y: target_y},
      remaining: player.bomb_left
    })

    Rails.logger.debug "Player #{player.id} set bomb at (#{target_x},#{target_y})"
  end

  def valid_dynamite_position?(player, target_x, target_y)
    # Can only place dynamite on current position or adjacent cells (manhattan distance <= 1)
    player_distance = (player.position_x - target_x).abs + (player.position_y - target_y).abs
    return false if player_distance > 1

    # Check if position is within map bounds
    map_data = game_round.game.game_map.map_data
    return false if target_y < 0 || target_y >= map_data.length
    return false if target_x < 0 || target_x >= map_data[target_y].length

    # Can place on empty space or water, but not on walls or items
    cell_value = map_data[target_y][target_x]
    case cell_value
    when MAP_BLANK, MAP_WATER
      true
    else
      false
    end
  end

  def valid_bomb_position?(player, target_x, target_y)
    # Same rules as dynamite for now
    valid_dynamite_position?(player, target_x, target_y)
  end

  def add_dynamite_to_round(x, y)
    # Store dynamite position for end-of-turn explosion
    @dynamites ||= []
    @dynamites << {x: x, y: y}
  end

  def add_bomb_to_round(x, y)
    # Store bomb position for end-of-turn explosion
    @bombs ||= []
    @bombs << {x: x, y: y}
  end

  def process_explosions
    # Process dynamite explosions
    if @dynamites&.any?
      @dynamites.each do |dynamite|
        explode_dynamite(dynamite[:x], dynamite[:y])
      end
      @dynamites = []
    end

    # Process bomb explosions
    if @bombs&.any?
      @bombs.each do |bomb|
        explode_bomb(bomb[:x], bomb[:y])
      end
      @bombs = []
    end
  end

  def explode_dynamite(x, y)
    Rails.logger.debug "Dynamite exploding at (#{x},#{y})"
    create_explosion(x, y, :dynamite)
  end

  def explode_bomb(x, y)
    Rails.logger.debug "Bomb exploding at (#{x},#{y})"
    create_explosion(x, y, :bomb)
  end

  def create_explosion(x, y, type)
    map_data = game_round.game.game_map.map_data

    # Destroy breakable walls in adjacent cells (following reference implementation)
    # Reference: game.rb#568-576

    # Check and destroy breakable walls in vertical directions (up/down)
    [1, -1].each do |direction|  # UP_SIDE = 1, DOWN_SIDE = -1
      target_x = x + direction
      if target_x >= 0 && target_x < map_data[0].length &&
          y >= 0 && y < map_data.length &&
          map_data[y][target_x] == MAP_BREAKABLE_WALL

        # Destroy the breakable wall
        map_data[y][target_x] = MAP_BLANK
        Rails.logger.debug "Destroyed breakable wall at (#{target_x}, #{y})"

        # Update the game map
        game_round.game.game_map.update!(map_data: map_data)

        create_game_event(nil, "WALL_DESTROYED", {
          position: {x: target_x, y: y},
          explosion_source: {x: x, y: y},
          explosion_type: type
        })
      end
    end

    # Check and destroy breakable walls in horizontal directions (left/right)
    [1, -1].each do |direction|  # RIGHT_SIDE = 1, LEFT_SIDE = -1
      target_y = y + direction
      if x >= 0 && x < map_data[0].length &&
          target_y >= 0 && target_y < map_data.length &&
          map_data[target_y][x] == MAP_BREAKABLE_WALL

        # Destroy the breakable wall
        map_data[target_y][x] = MAP_BLANK
        Rails.logger.debug "Destroyed breakable wall at (#{x}, #{target_y})"

        # Update the game map
        game_round.game.game_map.update!(map_data: map_data)

        create_game_event(nil, "WALL_DESTROYED", {
          position: {x: x, y: target_y},
          explosion_source: {x: x, y: y},
          explosion_type: type
        })
      end
    end

    # Create explosion event
    create_game_event(nil, "EXPLOSION", {
      position: {x: x, y: y},
      type: type
    })

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
    # Process both positive (1-5) and negative (6-9) items
    if item_index.between?(1, 9)
      # Only track positive items in inventory
      if item_index.between?(1, 5)
        player.get_positive_item(item_index)
      end

      score_bonus = ITEM_SCORES[item_index]
      player.score += score_bonus
      player.save!

      # Remove item from map
      remove_item_from_map(player.position_x, player.position_y)

      event_type = (score_bonus >= 0) ? "COLLECT_ITEM" : "HIT_TRAP"
      create_game_event(player, event_type, {
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
      next if enemy.killed?

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
      player.score += ENEMY_DISCOUNT
      player.status = :completed
      player.save!

      create_game_event(player, "ENEMY_ATTACK", {
        enemy_id: enemy.id,
        position: {x: player.position_x, y: player.position_y}
      })

      Rails.logger.debug "Enemy #{enemy.id} attacked player #{player.id}"
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
