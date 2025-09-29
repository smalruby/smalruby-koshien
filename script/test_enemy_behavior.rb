#!/usr/bin/env ruby

# Test enemy behavior with h_move player on 2024サンプルマップ1

h_move_ai = PlayerAi.find_by(name: "h_move") || PlayerAi.create!(
  name: "h_move",
  code: File.read("spec/fixtures/player_ai/stage_03_horizontal_move.rb")
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
  first_player_ai: h_move_ai,
  second_player_ai: wait_ai,
  game_map: game_map,
  battle_url: "test-enemy-behavior"
)

puts "Game created: #{game.id}"
puts "Testing enemy behavior with h_move player on 2024サンプルマップ1..."
puts "Expected: Enemy should interact with player and cause score deductions (-10 per hit)"

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
      else
        puts "  No enemies found in round"
      end

      # Show some game turns
      total_turns = round.game_turns.count
      puts "  Total turns: #{total_turns}"
      puts
    end

    # Check for enemy-player interactions
    total_negative_score = game.game_rounds.sum { |round|
      round.players.sum { |player| [player.score, 0].min }
    }

    if total_negative_score < 0
      puts "SUCCESS: Enemy interactions detected! Total negative score: #{total_negative_score}"
      puts "This indicates enemies successfully hit players and caused score deductions."
    else
      puts "INFO: No negative scores detected. This could mean:"
      puts "- Enemies and players didn't interact"
      puts "- Enemy collision logic not yet implemented"
      puts "- Players avoided enemies successfully"
    end
  end
else
  puts "Battle failed: #{result[:error]}"
end