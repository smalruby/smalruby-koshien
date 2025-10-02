require "smalruby3"

# 段階(8): 最後まで全領域を順に探索後、減点アイテムを避けてゴールに向かう
#
# 成功条件:
# - 最初の8ターンで全領域を探索し終えること
# - 減点アイテムを避けたうえで、最短経路でゴールまで向かうこと
# - このコード自体は無限ループだが、ゴール後にAiプロセスが停止すること
# - 途中に加点アイテムがあっても避けないこと
# - 途中に減点アイテムがあると避けること
# - 途中に妨害キャラクターがいても避けないこと
# - 移動した分の得点が加算されること (5回移動するごとに3点)
# - enemyと接触した回数だけ減点されること (1回接触するごとに-10点)

Stage.new(
  "Stage",
  lists: [
    {
      name: "探索位置", # list("$探索位置")
      value: [ # 探索する座標のリスト
        "2:2", "7:2", "12:2", "16:2",
        "2:7", "7:7", "12:7", "16:7",
        "2:12", "7:12", "12:12", "16:12",
        "2:16", "7:16", "12:16", "16:16"
      ]
    },
    {
      name: "通らない座標" # list("$通らない座標")
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
  koshien.connect_game(name: "except_nega")

  @turn_count = 0

  koshien.set_message("全領域探索中")
  8.times do
    2.times do
      @position = list("$探索位置")[1]
      list("$探索位置").delete_at(1)
      koshien.get_map_area(@position)
    end

    koshien.turn_over
    @turn_count += 1
  end

  koshien.set_message("ゴールに向かって移動中")
  loop do
    koshien.get_map_area(koshien.player)

    koshien.locate_objects(result: list("$通らない座標"), cent: "7:7", sq_size: 15, objects: "ABCD")
    koshien.calc_route(result: list("$最短経路"), src: koshien.player, dst: koshien.goal, except_cells: list("$通らない座標"))
    if list("$最短経路").length == 1
      # 減点アイテムで囲まれてしまっている場合は減点アイテムを避けずにゴールに向かう
      koshien.calc_route(result: list("$最短経路"))
    end
    koshien.move_to(list("$最短経路")[2])

    koshien.turn_over
    @turn_count += 1
  end
end
