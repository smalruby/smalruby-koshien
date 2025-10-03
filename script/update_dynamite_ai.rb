# Update dynamite AI with fixed code

dynamite_ai = PlayerAi.find_by(name: "dynamite")
if dynamite_ai
  dynamite_ai.update!(code: File.read("spec/fixtures/player_ai/stage_11_dynamite.rb"))
  puts "Updated dynamite AI"
  puts "Code has connect_game(name:): #{dynamite_ai.code.include?("connect_game(name:")}"
  puts "Code has illegal dynamite_left API: #{dynamite_ai.code.include?("koshien.dynamite_left")}"
  puts "Code has illegal map_at API: #{dynamite_ai.code.include?("koshien.map_at")}"
  puts "Code length: #{dynamite_ai.code.length}"
end
