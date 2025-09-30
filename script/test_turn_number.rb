#!/usr/bin/env ruby
require "smalruby3"

koshien = Smalruby3::Koshien.instance
puts "Initial turn_number: #{koshien.turn_number.inspect}"
puts "Initial turn_number class: #{koshien.turn_number.class}"

# Simulate turn_start
koshien.send(:handle_turn_start, {"turn_number" => 5})
puts "After handle_turn_start(5): #{koshien.turn_number.inspect}"

# Test comparison
if koshien.turn_number <= 8
  puts "Turn #{koshien.turn_number} is in exploration phase"
else
  puts "Turn #{koshien.turn_number} is in movement phase"
end
