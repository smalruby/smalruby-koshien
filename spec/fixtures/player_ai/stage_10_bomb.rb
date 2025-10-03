# frozen_string_literal: true

require "smalruby3"

Stage.new(
  backdrop: "color_06",
  variables: [
    {name: "turn_count"},
    {name: "center_x"},
    {name: "center_y"},
    {name: "goal_x"},
    {name: "goal_y"},
    {name: "bomb_placed"}
  ]
)

Sprite.new(
  costume: "emo_halloween1",
  x: 0,
  y: 0
) do
  koshien = self.koshien

  @turn_count = 0
  @bomb_placed = false

  koshien.connect_game(name: "bomb")

  # Get goal position
  @goal_x = koshien.goal_x
  @goal_y = koshien.goal_y

  koshien.set_message("爆弾戦略開始")

  50.times do
    # Get current positions
    koshien.enemy
    @enemy_x_val = koshien.enemy_x
    @enemy_y_val = koshien.enemy_y

    koshien.other_player
    @other_x = koshien.other_player_x
    @other_y = koshien.other_player_y

    @my_x = koshien.position_of_x(koshien.player)
    @my_y = koshien.position_of_y(koshien.player)

    # Calculate center position between self and other player
    if @other_x && @other_y
      @center_x = (@my_x + @other_x) / 2
      @center_y = (@my_y + @other_y) / 2
      variable("$center_x").write(@center_x)
      variable("$center_y").write(@center_y)
    else
      @center_x = @my_x
      @center_y = @my_y
    end

    # Explore the center area
    koshien.get_map_area("#{@center_x}:#{@center_y}")

    # Check distance to goal
    @goal_dist = ((@my_x - @goal_x).abs + (@my_y - @goal_y).abs)

    # If close to goal and haven't placed bomb yet, place bomb at current position and move to goal
    if @goal_dist <= 2 && !@bomb_placed
      koshien.set_message("ゴール直前爆弾設置")

      # Place bomb at current position
      koshien.set_bomb("#{@my_x}:#{@my_y}")
      @bomb_placed = true

      # Move to goal
      koshien.move_to("#{@goal_x}:#{@goal_y}")
    elsif @enemy_x_val && @enemy_y_val
      # Calculate distance to enemy
      @enemy_dist = ((@my_x - @enemy_x_val).abs + (@my_y - @enemy_y_val).abs)

      if @enemy_dist <= 3
        # Enemy is close, move away
        koshien.set_message("敵から逃げる")

        # Find safe direction (opposite of enemy)
        @dx = @my_x - @enemy_x_val
        @dy = @my_y - @enemy_y_val

        # Determine safe move
        if @dx.abs > @dy.abs
          # Move horizontally away from enemy
          @target_x = (@dx > 0) ? @my_x + 1 : @my_x - 1
          @target_y = @my_y
        else
          # Move vertically away from enemy
          @target_x = @my_x
          @target_y = (@dy > 0) ? @my_y + 1 : @my_y - 1
        end

        # Ensure target is within bounds
        @target_x = @target_x.clamp(0, 16)
        @target_y = @target_y.clamp(0, 16)

        koshien.move_to("#{@target_x}:#{@target_y}")
      else
        # Enemy is far, move towards goal
        koshien.set_message("ゴールへ移動")
        koshien.move_to("#{@goal_x}:#{@goal_y}")
      end
    else
      # No enemy info, just move to goal
      koshien.set_message("ゴールへ移動")
      koshien.move_to("#{@goal_x}:#{@goal_y}")
    end

    koshien.turn_over
    @turn_count += 1
  end
end
