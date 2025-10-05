require "smalruby3"

# 段階(12): 相手プレイヤーを意識してゴールに向かう
#
# 成功条件:
# - 最初の8ターンで全領域を探索し終えること
# - 相手プレイヤーの位置を取得すること (other_player, other_player_x, other_player_y)
# - 相手プレイヤーを避けながら、減点アイテムを避けたうえで、最短経路でゴールまで向かうこと
# - このコード自体は無限ループだが、ゴール後にAiプロセスが停止すること
# - 途中に加点アイテムがあっても避けないこと
# - 途中に減点アイテムがあると避けること
# - 途中に妨害キャラクターがいると避けること
# - 相手プレイヤーがいる位置も避けること
# - 移動した分の得点が加算されること (5回移動するごとに3点)
# - enemyと1度も接触しないこと

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
    # 減点アイテム、敵、そして相手プレイヤーの位置を避ける
    koshien.locate_objects(result: list("$通らない座標"), cent: "7:7", sq_size: 15, objects: "ABCD")
    list("$通らない座標").push(koshien.enemy)

    # 相手プレイヤーの位置も避ける対象に追加
    @other_pos = koshien.other_player
    if @other_pos
      list("$通らない座標").push(@other_pos)
      koshien.set_message("相手の位置:" + @other_pos.to_s + "を避ける")
    end

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

  def self.相手の位置情報を表示
    # other_player_x と other_player_y を使用 (使用回数制限なし)
    @other_x = koshien.other_player_x
    @other_y = koshien.other_player_y
    if @other_x && @other_y
      koshien.set_message("相手:(" + @other_x.to_s + "," + @other_y.to_s + ")")
    end
  end

  def self.相手周辺のマップ情報を取得する
    @other_pos = koshien.other_player
    if @other_pos
      koshien.get_map_area(@other_pos)
      @action_count += 1
      koshien.set_message("相手周辺探索:" + @other_pos.to_s)
    end

    ゴールへの最短経路を調べる
  end

  koshien.connect_game(name: "other_player")

  @turn_count = 0
  @action_count = 0

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
      # 奇数ターンは自分周辺、偶数ターンは相手周辺のマップ情報を取得
      if @turn_count % 2 == 1
        マップ情報を取得する(koshien.player)
      else
        相手周辺のマップ情報を取得する
      end
    end

    # 相手プレイヤーの位置情報を定期的に表示 (使用回数制限なし)
    if @turn_count % 5 == 0
      相手の位置情報を表示
    end

    if @action_count < 2
      最短経路を進む
    end

    ターン終了
  end
end
