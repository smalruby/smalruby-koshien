# プリセットAIの作成
preset_ais = [
  {
    name: "ゴール優先AI",
    code: "# ゴールを最優先で目指すAI\nloop do\n  move_to_goal\nend",
    author: "system"
  },
  {
    name: "アイテム優先AI",
    code: "# アイテム収集を最優先にするAI\nloop do\n  collect_items\nend",
    author: "system"
  },
  {
    name: "前半アイテム後半ゴールAI",
    code: "# 前半はアイテム、後半はゴールを目指すAI\nif turn < 25\n  collect_items\nelse\n  move_to_goal\nend",
    author: "system"
  },
  {
    name: "サンプルAI",
    code: File.read("/Users/kouji/work/smalruby/smalruby3-develop/tmp/vendor/smalruby-koshien/src/samples/smpl31/player_AI.rb"),
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
    line.strip.split(',').map(&:to_i)
  end
end

def find_goal_position(players_data)
  players_data.each_with_index do |row, y|
    row.each_with_index do |cell, x|
      if cell == 1
        return {x: x, y: y}
      end
    end
  end
  {x: 16, y: 16} # デフォルト位置
end

sample_maps_base_path = "/Users/kouji/work/smalruby/smalruby3-develop/tmp/vendor/smalruby-koshien/sample_maps/2024サンプルマップ"
preset_maps = []

(1..10).each do |i|
  map_dir = "#{sample_maps_base_path}/map_#{format('%02d', i)}"

  if Dir.exist?(map_dir)
    begin
      map_data = load_csv_map("#{map_dir}/map.dat")
      players_data = load_csv_map("#{map_dir}/players.dat")
      goal_position = find_goal_position(players_data)

      preset_maps << {
        name: "2024サンプルマップ#{i}",
        description: "2024年度コンテスト用サンプルマップ#{i}",
        map_data: map_data,
        map_height: Array.new(map_data.size) { Array.new(map_data.first.size) { 0 } },
        goal_position: goal_position
      }
    rescue => e
      puts "Warning: Could not load map #{i}: #{e.message}"
    end
  end
end

# 既存のランダムマップも保持
(1..10).each do |i|
  preset_maps << {
    name: "ランダムマップ#{i}",
    description: "プリセットランダムマップ#{i}",
    map_data: Array.new(10) { Array.new(10) { rand(3) } },
    map_height: Array.new(10) { Array.new(10) { 0 } },
    goal_position: {x: 9, y: 9}
  }
end

preset_maps.each do |map_data|
  GameMap.find_or_create_by!(name: map_data[:name]) do |map|
    map.description = map_data[:description]
    map.map_data = map_data[:map_data]
    map.map_height = map_data[:map_height]
    map.goal_position = map_data[:goal_position]
  end
end

puts "Seeded #{PlayerAi.count} player AIs"
puts "Seeded #{GameMap.count} game maps"