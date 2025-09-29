require "smalruby3"

# 段階(7): 最後まで全領域を順に探索後、ゴールに向かう
#
# 成功条件:
# - 最初の8ターンで全領域を探索し終えること
# - 最短経路でゴールまで向かうこと
# - 途中に加点アイテムがあっても避けないこと
# - 途中に減点アイテムがあっても避けないこと
# - 途中に妨害キャラクターがいても避けないこと

Stage.new(
  "Stage",
  lists: [
    {
      name: "探索位置" # list("$探索位置")
    },
    {
      name: "最短経路" # list("$最短経路")
    }
  ]
) do
end

Sprite.new(
  "スプライト1"
) do
  koshien.connect_game(name: "goal")

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

  koshien.set_message("探索完了")

  # 残りのターンがあれば続行
  loop do
    koshien.calc_route(result: list("$最短経路"))
    koshien.move_to(list("$最短経路")[2])
    koshien.turn_over
    turn_count += 1

    koshien.set_message("ゴールに向かって移動中")
  end
end
