#!/usr/bin/env ruby

# Test enemy collision by using a goal-seeking AI that should encounter enemy at goal

goal_seeker_code = <<~RUBY
  require "smalruby3"
  
  Stage.new("Stage", lists: []) do
  end
  
  Sprite.new("スプライト1") do
    koshien.connect_game(name: "goal_seeker")
  
    # Move toward goal where enemy is located
    50.times do |turn|
      current_x = koshien.player_x
      current_y = koshien.player_y
      goal_x = koshien.goal_x
      goal_y = koshien.goal_y
  
      # Simple pathfinding toward goal
      if current_x < goal_x
        koshien.move_to(koshien.position(current_x + 1, current_y))
      elsif current_x > goal_x
        koshien.move_to(koshien.position(current_x - 1, current_y))
      elsif current_y < goal_y
        koshien.move_to(koshien.position(current_x, current_y + 1))
      elsif current_y > goal_y
        koshien.move_to(koshien.position(current_x, current_y - 1))
      end
  
      koshien.set_message("Moving to goal: (" + goal_x.to_s + ", " + goal_y.to_s + ")")
      koshien.turn_over
    end
  end
RUBY

goal_seeker_ai = PlayerAi.find_by(name: "goal_seeker") || PlayerAi.create!(
  name: "goal_seeker",
  code: goal_seeker_code
)

wait_ai = PlayerAi.find_by(name: "wait_only") || PlayerAi.create!(
  name: "wait_only_test",
  code: File.read("spec/fixtures/player_ai/stage_02_wait_only.rb")
)

game_map = GameMap.find_by(name: "2024サンプルマップ1")
unless game_map
  puts "GameMap not found!"
  exit 1
end

game = Game.create!(
  first_player_ai: goal_seeker_ai,
  second_player_ai: wait_ai,
  game_map: game_map,
  battle_url: "test-enemy-collision"
)

puts "Game created: #{game.id}"
puts "Testing enemy collision with goal-seeking player on 2024サンプルマップ1..."
puts "Goal position: #{game_map.goal_position.inspect}"
puts "Expected: Player should encounter enemy at goal and get score penalties"

engine = GameEngine.new(game)
result = engine.execute_battle

puts "Battle result:"
puts result.inspect

if result[:success]
  puts "Game completed successfully!"
  puts "Winner: #{game.reload.winner}"
  puts "Status: #{game.status}"

  if game.game_rounds.any?
    puts "\n=== Round Results ==="
    game.game_rounds.each do |round|
      puts "Round #{round.round_number}:"

      round.players.each_with_index do |player, index|
        puts "  Player #{index + 1} (#{player.player_ai.name}): Score = #{player.score}"
        puts "    Position: (#{player.position_x}, #{player.position_y})"
        puts "    Status: #{player.status}"
      end

      if round.enemies.any?
        puts "  Enemies:"
        round.enemies.each_with_index do |enemy, index|
          puts "    Enemy #{index + 1}: Position = (#{enemy.position_x}, #{enemy.position_y}), State = #{enemy.state}"
          puts "      Previous Position: (#{enemy.previous_position_x}, #{enemy.previous_position_y})"
        end
      end

      total_turns = round.game_turns.count
      puts "  Total turns: #{total_turns}"
      puts
    end

    # Check for enemy-player interactions
    total_negative_score = game.game_rounds.sum { |round|
      round.players.sum { |player| [player.score, 0].min }
    }

    if total_negative_score < 0
      puts "SUCCESS: Enemy collisions detected! Total negative score: #{total_negative_score}"
      puts "This confirms enemy collision detection is working correctly."
    else
      puts "INFO: No negative scores detected."
      puts "Goal position: #{game_map.goal_position.inspect}"
      first_player = game.game_rounds.first.players.first
      puts "Player final position: (#{first_player.position_x}, #{first_player.position_y})"
      puts "Distance to goal: #{(first_player.position_x - game_map.goal_position["x"]).abs + (first_player.position_y - game_map.goal_position["y"]).abs}"
    end
  end
else
  puts "Battle failed: #{result[:error]}"
end
