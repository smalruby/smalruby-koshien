require "smalruby3"

# 段階(6): 最後まで全領域を順に探索するだけ
#
# 成功条件:
# - 50ターンまでターンが進むこと
# - 最初から最後までPlayerの位置が変わらないこと
# - 各ターンで、マップ情報の探索結果を踏まえた情報を、AiEngineからAiプロセスの標準入力にわたすこと

Stage.new(
  "Stage",
  lists: [
    {
      name: "探索位置" # list("$探索位置")
    }
  ]
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "all_explore")

  # 探索する座標のリストを準備
  explore_positions = [
    "2:2", "7:2", "12:2", "16:2",
    "2:7", "7:7", "12:7", "16:7",
    "2:12", "7:12", "12:12", "16:12",
    "2:16", "7:16", "12:16", "16:16"
  ]

  turn_count = 0
  explore_positions.cycle do |position|
    break if turn_count >= 50

    # 各位置を順次探索
    koshien.get_map_area(position)

    # 探索した位置をリストに記録
    list("$探索位置").push(position)

    # デバッグ用メッセージ
    koshien.set_message("全領域探索中: #{position}")

    koshien.turn_over
    turn_count += 1
  end

  # 残りのターンがあれば続行
  while turn_count < 50
    koshien.set_message("探索完了、待機中")
    koshien.turn_over
    turn_count += 1
  end
end
