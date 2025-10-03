# Update test AI records with corrected code from fixture files

# Update bomb AI
bomb_ai = PlayerAi.find_by(name: "bomb")
if bomb_ai
  bomb_ai.update!(code: File.read("spec/fixtures/player_ai/stage_10_bomb.rb"))
  puts "Updated bomb AI"
  puts "Code has connect_game(name:): #{bomb_ai.code.include?("connect_game(name:")}"
end

# Update except_enemy AI
except_enemy_ai = PlayerAi.find_by(name: "except_enemy")
if except_enemy_ai
  except_enemy_ai.update!(code: File.read("spec/fixtures/player_ai/stage_09_except_enemy.rb"))
  puts "Updated except_enemy AI"
  puts "Code has connect_game(name:): #{except_enemy_ai.code.include?("connect_game(name:")}"
end

# Update dynamite AI
dynamite_ai = PlayerAi.find_by(name: "dynamite")
if dynamite_ai
  dynamite_ai.update!(code: File.read("spec/fixtures/player_ai/stage_11_dynamite.rb"))
  puts "Updated dynamite AI"
  puts "Code has connect_game(name:): #{dynamite_ai.code.include?("connect_game(name:")}"
end

puts "Database update complete!"
