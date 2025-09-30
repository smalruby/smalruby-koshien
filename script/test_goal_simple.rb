#!/usr/bin/env ruby
require "smalruby3"

Stage.new("Stage") do
end

Sprite.new("Player") do
  koshien.connect_game(name: "test_simple")

  current_turn = (koshien.turn_number > 0) ? koshien.turn_number : 1
  puts "Current turn: #{current_turn}"

  if current_turn <= 2
    puts "Exploration phase"
    koshien.set_message("Exploring...")
    koshien.get_map_area("2:2")
    koshien.get_map_area("7:2")
  else
    puts "Movement phase"
    koshien.set_message("Moving to goal...")
    # Try to move
    koshien.move_to("2:1")
  end

  puts "Calling turn_over"
  koshien.turn_over
  puts "turn_over returned"
end

puts "Script completed"
