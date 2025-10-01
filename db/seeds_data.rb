# プリセットAIの作成
preset_ais = [
  {
    name: "ゴール優先AI",
    code: File.read(Rails.root.join("db/seeds_data/player_ai_goal.rb")),
    author: "system"
  },
  {
    name: "アイテム優先AI",
    code: File.read(Rails.root.join("db/seeds_data/player_ai_item.rb")),
    author: "system"
  },
  {
    name: "前半アイテム後半ゴールAI",
    code: File.read(Rails.root.join("db/seeds_data/player_ai_item_goal.rb")),
    author: "system"
  }
]

preset_ais.each do |ai_data|
  PlayerAi.find_or_create_by!(name: ai_data[:name]) do |ai|
    ai.code = ai_data[:code]
    ai.author = ai_data[:author]
  end
end

# プリセットマップの作成（2024サンプルマップから）
def load_csv_map(file_path)
  File.readlines(file_path).map do |line|
    line.strip.split(",").map(&:to_i)
  end
end

def find_goal_position(map_data)
  map_data.each_with_index do |row, y|
    row.each_with_index do |cell, x|
      if cell == 3  # MAP_GOAL
        return {"x" => x, "y" => y}
      end
    end
  end
  {"x" => 16, "y" => 16} # デフォルト位置
end

preset_maps = []

# 動的にgame_map_*ディレクトリを探索
map_dirs = Dir.glob(Rails.root.join("db/seeds_data/game_map_*")).sort

map_dirs.each do |map_dir|
  map_number = File.basename(map_dir).match(/game_map_(\d+)/)[1].to_i

  begin
    map_data = load_csv_map("#{map_dir}/map.dat")
    players_data = load_csv_map("#{map_dir}/players.dat")
    items_data = load_csv_map("#{map_dir}/items.dat")
    goal_position = find_goal_position(map_data)

    preset_maps << {
      name: "2024サンプルマップ#{map_number}",
      description: "2024年度コンテスト用サンプルマップ#{map_number}",
      map_data: map_data,
      map_height: Array.new(map_data.size) { Array.new(map_data.first.size) { 0 } },
      goal_position: goal_position,
      players_data: players_data,
      items_data: items_data
    }
  rescue => e
    puts "Warning: Could not load map #{map_number}: #{e.message}"
  end
end

preset_maps.each do |map_data|
  GameMap.find_or_create_by!(name: map_data[:name]) do |map|
    map.description = map_data[:description]
    map.map_data = map_data[:map_data]
    map.map_height = map_data[:map_height]
    map.goal_position = map_data[:goal_position]
    map.players_data = map_data[:players_data]
    map.items_data = map_data[:items_data]
  end
end

puts "Seeded #{PlayerAi.count} player AIs"
puts "Seeded #{GameMap.count} game maps"
