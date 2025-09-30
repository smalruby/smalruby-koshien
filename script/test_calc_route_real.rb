#!/usr/bin/env ruby
# Test calc_route with real game scenario

require_relative "../config/environment"

# Setup koshien instance
koshien = Smalruby3::Koshien.instance

# Simulate a real game turn data after exploration
koshien.instance_variable_set(:@current_turn_data, {
  "visible_map" => {
    # Create a simple explored path from (1,1) to goal (8,9)
    "1_1" => 0, "2_1" => 0, "3_1" => 0, "4_1" => 0, "5_1" => 0,
    "1_2" => 0, "2_2" => 0, "3_2" => 0, "4_2" => 0, "5_2" => 0,
    "1_3" => 0, "2_3" => 0, "3_3" => 0, "4_3" => 0, "5_3" => 0,
    "6_6" => 0, "7_7" => 0, "8_8" => 0, "8_9" => 0  # Path to goal
  },
  "game_map" => {"size" => 17},
  "player" => {"position_x" => 1, "position_y" => 1}
})

# Test in JSON mode
ENV["KOSHIEN_JSON_MODE"] = "true"

puts "Testing calc_route with real scenario..."
puts "Start: (1,1), Goal: (8,9)"
puts

result_list = Smalruby3::List.new
koshien.calc_route(result: result_list, src: "1:1", dst: "8:9")

puts "Result list length: #{result_list.length}"
if result_list.length > 0
  (1..result_list.length).each do |i|
    puts "  [#{i}]: #{result_list[i]}"
  end

  puts "\nTesting list access:"
  puts "  [1] = #{result_list[1]}"
  puts "  [2] = #{result_list[2]}"  # This is what goal AI tries to access

  if result_list[2].nil?
    puts "\n⚠️  ERROR: list[2] is nil! This will cause goal AI to fail."
  else
    puts "\n✓ list[2] exists and can be used for move_to"
  end
else
  puts "\n⚠️  ERROR: Result list is empty!"
end
