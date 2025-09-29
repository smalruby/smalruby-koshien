#!/usr/bin/env ruby

# Test enemy angry mode - should activate at turn 41

# Create a simple AI that moves slowly to test 50 turns
slow_ai_code = <<~RUBY
  require "smalruby3"

  Stage.new("Stage", lists: []) do
  end

  Sprite.new("スプライト1") do
    koshien.connect_game(name: "slow_mover")

    50.times do |turn|
      current_x = koshien.player_x
      current_y = koshien.player_y

      # Move very slowly to ensure we reach turn 41+
      if turn.even?
        koshien.move_to(koshien.position(current_x + 1, current_y))
      end

      koshien.set_message("Turn " + (turn + 1).to_s + " - checking enemy state")
      koshien.turn_over
    end
  end
RUBY

slow_ai = PlayerAi.find_by(name: "slow_mover") || PlayerAi.create!(
  name: "slow_mover",
  code: slow_ai_code
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
  first_player_ai: slow_ai,
  second_player_ai: wait_ai,
  game_map: game_map,
  battle_url: "test-enemy-angry"
)

puts "Game created: #{game.id}"
puts "Testing enemy angry mode activation at turn 41..."
puts "Enemy should change from normal_state to angry at turn 41"

engine = GameEngine.new(game)
result = engine.execute_battle

puts "Battle result:"
puts result.inspect

if result[:success]
  puts "Game completed successfully!"

  if game.game_rounds.any?
    puts "\n=== Enemy State Analysis ==="
    game.game_rounds.each do |round|
      puts "Round #{round.round_number}:"

      if round.enemies.any?
        enemy = round.enemies.first
        puts "  Enemy final state: #{enemy.state}"
        puts "  Enemy final position: (#{enemy.position_x}, #{enemy.position_y})"
        puts "  Enemy previous position: (#{enemy.previous_position_x}, #{enemy.previous_position_y})"
      end

      total_turns = round.game_turns.count
      puts "  Total turns completed: #{total_turns}"

      if total_turns >= 41
        puts "  ✅ Turn 41+ reached - Enemy should be in angry mode"
      else
        puts "  ❌ Only #{total_turns} turns - Enemy should be in normal mode"
      end

      puts
    end

    # Check final player positions for angry mode effect
    first_round = game.game_rounds.first
    first_player = first_round.players.first
    puts "Player final position: (#{first_player.position_x}, #{first_player.position_y})"
    puts "Player score: #{first_player.score}"

    if first_round.enemies.any?
      enemy = first_round.enemies.first
      distance = (first_player.position_x - enemy.position_x).abs + (first_player.position_y - enemy.position_y).abs
      puts "Distance between player and enemy: #{distance}"

      if enemy.state == "angry"
        puts "🐉 SUCCESS: Enemy is in angry mode!"
        puts "In angry mode, enemy should pursue players across entire map"
      else
        puts "ℹ️  Enemy is in #{enemy.state} mode"
      end
    end
  end
else
  puts "Battle failed: #{result[:error]}"
end
