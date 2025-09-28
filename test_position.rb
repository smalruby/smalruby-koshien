require "smalruby3"

Stage.new("Stage", lists: []) do
end

Sprite.new("スプライト1") do
  koshien.connect_game(name: "position_test")

  puts "Turn 1:"
  puts "player_x: #{koshien.player_x}"
  puts "player_y: #{koshien.player_y}"
  puts "position(2,3): #{koshien.position(2, 3)}"

  # Try to move and see what happens next turn
  koshien.move_to(koshien.position(2, 3))
  koshien.turn_over

  puts "Turn 2:"
  puts "player_x: #{koshien.player_x}"
  puts "player_y: #{koshien.player_y}"

  koshien.turn_over
end