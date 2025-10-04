require "smalruby3"

# 段階(11): ダイナマイトを使ってゴールに向かう
#
# 成功条件:
# - 最初の8ターンで全領域を探索し終えること
# - 減点アイテムを避けたうえで、最短経路でゴールまで向かうこと
# - このコード自体は無限ループだが、ゴール後にAiプロセスが停止すること
# - 途中に加点アイテムがあっても避けないこと
# - 途中に減点アイテムがあると避けること
# - 途中に妨害キャラクターがいると避けること
# - 移動した分の得点が加算されること (5回移動するごとに3点)
# - enemyと1度も接触しないこと
# - ゴールまで2マスとゴールまで1マスのときに、爆弾を設置してゴールに到達すること
# - 爆弾は2回だけ設置すること
# - ゴールから2マスより多く離れていて、ゴールの方向に壊せる壁があればダイナマイトで破壊すること

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
  def self.ゴールへの最短経路を調べる
    koshien.locate_objects(result: list("$通らない座標"), cent: "7:7", sq_size: 15, objects: "ABCD")
    list("$通らない座標").push(koshien.enemy)
    koshien.calc_route(result: list("$最短経路"), src: koshien.player, dst: koshien.goal, except_cells: list("$通らない座標"))
    if list("$最短経路").length == 1
      # 減点アイテムで囲まれてしまっている場合は減点アイテムを避けずにゴールに向かう
      koshien.calc_route(result: list("$最短経路"))
    end
  end

  def self.最短経路を進む
    koshien.move_to(list("$最短経路")[2])
    @action_count += 1
  end

  def self.マップ情報を取得する(position)
    koshien.get_map_area(position)
    @action_count += 1

    ゴールへの最短経路を調べる
  end

  def self.ターン終了
    koshien.turn_over
    @turn_count += 1
    @action_count = 0
  end

  koshien.connect_game(name: "dynamite")

  @turn_count = 0
  @bomb_count = 0
  @dynamite_count = 0
  @action_count = 0
  @prev_position = koshien.player

  koshien.set_message("全領域探索中")
  8.times do
    2.times do
      マップ情報を取得する(list("$探索位置")[1])
      list("$探索位置").delete_at(1)
    end

    ターン終了
  end

  koshien.set_message("ゴールに向かって移動中")
  loop do
    if @action_count == 0 && list("$最短経路").length > 2
      マップ情報を取得する(koshien.player)
    end

    # ゴールまで2マス以下の時に1つ前の位置に爆弾を設置
    if @action_count < 2 && @bomb_count < 2 && (list("$最短経路").length == 2 || list("$最短経路").length == 3) && @prev_position != koshien.player
      koshien.set_message(list("$最短経路").length.to_s + "マス前爆弾:".to_s + @prev_position.to_s)
      koshien.set_bomb(@prev_position)
      @bomb_count += 1
      @action_count += 1
    end

    # ゴールから2マスより多く離れている場合、1マス先の最短経路の壁のうちゴールの方向に壊せる壁があるか調べる
    if @action_count < 2 && @dynamite_count < 2 && list("$最短経路").length > 3
      @next_my_position = list("$最短経路")[2]
      @my_x = koshien.position_of_x(@next_my_position)
      @my_y = koshien.position_of_y(@next_my_position)
      @goal_x = koshien.position_of_x(koshien.goal)
      @goal_y = koshien.position_of_y(koshien.goal)

      @dx = @goal_x - @my_x
      @dy = @goal_y - @my_y

      # Prioritize the direction with larger distance
      if @dx.abs > @dy.abs
        # Move horizontally towards goal
        @check_x = (@dx > 0) ? @my_x + 1 : @my_x - 1
        @check_y = @my_y
      else
        # Move vertically towards goal
        @check_x = @my_x
        @check_y = (@dy > 0) ? @my_y + 1 : @my_y - 1
      end

      @check_pos = koshien.position(@check_x, @check_y)
      @check_map = koshien.map(@check_pos)
      @next_map = koshien.map(@next_my_position)

      # If there's a breakable wall (value 5), use dynamite
      if @check_map == koshien.object("壊せる壁") && (@next_map == koshien.object("空間") || @next_map == koshien.object("水たまり"))
        koshien.set_message("壁破壊:".to_s + @check_pos.to_s + "、" + @next_my_position.to_s)
        koshien.set_dynamite(@next_my_position)
        @dynamite_count += 1
        @action_count += 1
      end
    end

    if @action_count < 2
      @prev_position = koshien.player
      最短経路を進む
    end

    ターン終了
  end
end
