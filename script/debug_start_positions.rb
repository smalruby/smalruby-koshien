#!/usr/bin/env ruby

game_map = GameMap.find_by(name: "2024サンプルマップ1")

# Simulate initialize_players for round 1
start_positions = []
game_map.players_data.each_with_index do |row, y|
  row.each_with_index do |cell, x|
    if cell == 1
      start_positions << {x: x, y: y}
    end
  end
end

puts "Round 1 start positions:"
puts "  Found: #{start_positions.inspect}"
puts ""

# Create a test game to see actual behavior
player_ai = PlayerAi.find_by(name: "goal")
game = Game.create!(
  first_player_ai: player_ai,
  second_player_ai: player_ai,
  game_map: game_map,
  battle_url: "test-start-pos-debug",
  status: :in_progress
)

round = game.game_rounds.create!(
  round_number: 1,
  status: :preparing,
  item_locations: {}
)

# Manually call the same logic as initialize_players
game_map = game.game_map
test_start_positions = []
game_map.players_data.each_with_index do |row, y|
  row.each_with_index do |cell, x|
    if cell == 1
      test_start_positions << {x: x, y: y}
    end
  end
end

puts "Test game initialization:"
puts "  Start positions: #{test_start_positions.inspect}"

[game.first_player_ai, game.second_player_ai].each_with_index do |ai, index|
  position = test_start_positions[index]
  puts "  Player #{index + 1} (#{ai.name}, ID: #{ai.id}): position #{position.inspect}"

  round.players.create!(
    player_ai: ai,
    position_x: position[:x],
    position_y: position[:y],
    previous_position_x: position[:x],
    previous_position_y: position[:y],
    score: 0,
    character_level: 1,
    dynamite_left: 2,
    bomb_left: 2,
    walk_bonus_counter: 0,
    acquired_positive_items: [0, 0, 0, 0, 0, 0],
    status: :playing,
    my_map: Array.new(17) { Array.new(17, -1) },
    map_fov: Array.new(17) { Array.new(17, -1) }
  )
end

puts ""
puts "Created players:"
round.players.order(:id).each_with_index do |p, i|
  puts "  Player #{i + 1}: (#{p.position_x}, #{p.position_y})"
end

game.destroy
puts ""
puts "Test game destroyed"
