# frozen_string_literal: true

require "smalruby3"

Stage.new(
  backdrop: "color_06", # default yellow backdrop
  variables: [
    {
      name: "turn_count" # variable("$turn_count")
    },
    {
      name: "center_x" # variable("$center_x")
    },
    {
      name: "center_y" # variable("$center_y")
    }
  ]
)

Sprite.new(
  costume: "emo_halloween1", # default costume
  x: 0,
  y: 0
) do
  koshien = self.koshien

  @turn_count = 0

  koshien.connect_game

  koshien.set_message("移動開始")

  50.times do
    # Get current enemy position
    koshien.enemy
    @enemy_x_val = koshien.enemy_x
    @enemy_y_val = koshien.enemy_y

    # Get other player position
    koshien.other_player
    @other_x = koshien.other_player_x
    @other_y = koshien.other_player_y

    # Calculate center position between self and other player
    @my_x = koshien.position_of_x(koshien.player)
    @my_y = koshien.position_of_y(koshien.player)

    if @other_x && @other_y
      # Calculate center point between players
      @center_x = (@my_x + @other_x) / 2
      @center_y = (@my_y + @other_y) / 2
      variable("$center_x").write(@center_x)
      variable("$center_y").write(@center_y)
    else
      # If other player not visible, explore around self
      @center_x = @my_x
      @center_y = @my_y
    end

    # Explore the center area
    koshien.get_map_area("#{@center_x}:#{@center_y}")

    # Check enemy position and avoid if close
    if @enemy_x_val && @enemy_y_val
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
        # Enemy is far, move towards center/other player
        koshien.set_message("中心点に移動")
        koshien.move_to("#{@center_x}:#{@center_y}")
      end
    else
      # No enemy info, just explore center
      koshien.set_message("探索中")
      koshien.move_to("#{@center_x}:#{@center_y}")
    end

    koshien.turn_over
    @turn_count += 1
  end
end
