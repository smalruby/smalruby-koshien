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
  }
]

preset_ais.each do |ai_data|
  PlayerAi.find_or_create_by!(name: ai_data[:name]) do |ai|
    ai.code = ai_data[:code]
    ai.author = ai_data[:author]
  end
end

# プリセットマップの作成（簡単なサンプル）
preset_maps = (1..10).map do |i|
  {
    name: "map#{i}",
    description: "プリセットマップ#{i}",
    map_data: Array.new(10) { Array.new(10) { rand(3) } }, # 10x10のランダムマップ
    map_height: Array.new(10) { Array.new(10) { 0 } },     # 高さ情報
    goal_position: {x: 9, y: 9}                          # ゴール位置
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
