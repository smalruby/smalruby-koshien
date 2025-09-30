#!/usr/bin/env ruby
# Simple test to verify calc_route works in isolation

ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "smalruby3"

# Create a simple test map with no obstacles
simple_map = Array.new(17) { Array.new(17, 0) }  # All open spaces

# Create a koshien instance
koshien = Smalruby3::Koshien.instance

# Enable JSON mode
ENV["KOSHIEN_JSON_MODE"] = "true"

# Mock the map data
allow(koshien).to receive(:build_map_data_from_game_state).and_return(simple_map)

# Create a result list
result = Smalruby3::List.new

# Test calc_route from (2,1) to (8,9)
puts "Testing calc_route from (2,1) to (8,9)..."
koshien.calc_route(result: result, src: "2:1", dst: "8:9")

puts "Route length: #{result.length}"
puts "First 5 positions:"
(1..([5, result.length].min)).each do |i|
  puts "  [#{i}]: #{result[i]}"
end

if result.length >= 2
  puts "\nSecond position (where AI would move): #{result[2]}"
else
  puts "\nERROR: Route has less than 2 elements!"
end
