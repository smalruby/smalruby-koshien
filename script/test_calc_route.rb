#!/usr/bin/env ruby
require "smalruby3"

koshien = Smalruby3::Koshien.instance
route = Smalruby3::List.new

# Set JSON mode to use real pathfinding
koshien.instance_variable_set(:@json_mode, true)

# Mock game state with simple map
simple_map = Array.new(17) { Array.new(17, 0) }  # 17x17 open map
allow(koshien).to receive(:build_map_data_from_game_state).and_return(simple_map)

# Mock player position
koshien.instance_variable_set(:@current_turn_data, {
  "current_player" => {"x" => 2, "y" => 1}
})

# Mock goal position
koshien.instance_variable_set(:@game_state, {
  "game_map" => {"goal_position" => {"x" => 8, "y" => 9}}
})

puts "Testing calc_route from player (2:1) to goal (8:9)..."
koshien.calc_route(result: route)

puts "Route length: #{route.length}"
puts "Route[1] (current): #{route[1]}"
puts "Route[2] (next step): #{route[2]}"
puts "Route[3]: #{route[3]}"
puts "Route (all): #{route.map { |i| route[i] }.join(' -> ')}"