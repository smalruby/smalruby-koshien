#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for stage_07 calc_route
require_relative "../config/environment"

# Find the goal AI
goal_ai = PlayerAi.find_by(name: "goal")
unless goal_ai
  puts "ERROR: goal AI not found"
  exit 1
end

puts "Found goal AI: #{goal_ai.name} (ID: #{goal_ai.id})"
puts "\nAI Code:"
puts "=" * 50
puts goal_ai.code
puts "=" * 50

# Find game map
game_map = GameMap.find_by(name: "2024サンプルマップ1")
unless game_map
  puts "ERROR: 2024サンプルマップ1 not found"
  exit 1
end

puts "\nGame Map: #{game_map.name}"
puts "Goal Position: (#{game_map.goal_position["x"]}, #{game_map.goal_position["y"]})"
puts "Map Size: #{game_map.map_data.size}x#{game_map.map_data.first.size}"

# Create a test game
game = Game.create!(
  first_player_ai: goal_ai,
  second_player_ai: PlayerAi.find_by(name: "wait_only"),
  game_map: game_map,
  battle_url: "test-stage07-debug-#{Time.now.to_i}"
)

puts "\nCreated test game: #{game.id}"
puts "Running battle..."

begin
  engine = GameEngine.new(game)
  result = engine.execute_battle

  puts "\nBattle Result:"
  puts "Success: #{result[:success]}"
  puts "Winner: #{result[:winner] || "None"}"

  # Check game events for calc_route calls
  calc_route_events = GameEvent.joins(game_turn: {game_round: :game})
    .where(games: {id: game.id})
    .where("event_type LIKE ?", "%ROUTE%")

  if calc_route_events.any?
    puts "\nFound #{calc_route_events.count} route-related events:"
    calc_route_events.each do |event|
      puts "  Turn #{event.game_turn.turn_number}: #{event.event_type} - #{event.event_data}"
    end
  else
    puts "\nNo route-related events found"
  end

  # Check final positions
  game.reload
  final_round = game.game_rounds.last
  final_round&.players&.each do |player|
    puts "\n#{player.player_ai.name}:"
    puts "  Final Position: (#{player.position_x}, #{player.position_y})"
    puts "  Score: #{player.score}"
    puts "  Status: #{player.status}"
    puts "  Turns completed: #{final_round.game_turns.count}"
  end
rescue => e
  puts "\nERROR: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
