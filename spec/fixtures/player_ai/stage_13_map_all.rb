require "smalruby3"

# 段階(13): マップ全体を取得して独自経路探索でゴールに向かう
#
# 成功条件:
# - 最初の8ターンで全領域を探索し終えること
# - map_all を使って探索済みマップのスナップショットを取得すること
# - map_from を使ってマップデータから情報を参照すること
# - goal_x, goal_y, enemy_x, enemy_y を使って座標演算を行うこと
# - 簡易的なダイクストラ法で最短経路を自前計算すること
# - 減点アイテムを避けたうえで、最短経路でゴールまで向かうこと
# - このコード自体は無限ループだが、ゴール後にAiプロセスが停止すること
# - 途中に加点アイテムがあっても避けないこと
# - 途中に減点アイテムがあると避けること
# - 途中に妨害キャラクターがいると避けること
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
  def self.簡易ダイクストラ法で最短経路を計算
    # map_all でマップスナップショットを取得
    @map_snapshot = koshien.map_all

    # goal_x, goal_y, enemy_x, enemy_y を使用して座標を取得
    @goal_x = koshien.goal_x
    @goal_y = koshien.goal_y
    @enemy_x = koshien.enemy_x
    @enemy_y = koshien.enemy_y

    # 現在位置を取得
    @my_x = koshien.player_x
    @my_y = koshien.player_y

    # 減点アイテム、敵の位置を避ける座標リストを作成
    list("$通らない座標").clear
    koshien.locate_objects(result: list("$通らない座標"), cent: "7:7", sq_size: 15, objects: "ABCD")
    if @enemy_x && @enemy_y
      list("$通らない座標").push(koshien.position(@enemy_x, @enemy_y))
    end

    # 簡易的なダイクストラ法による経路探索
    list("$最短経路").clear

    # 探索済み座標を記録する辞書（座標文字列 => 距離）
    @distances = {}
    # 前の座標を記録する辞書（座標文字列 => 前の座標文字列）
    @previous = {}
    # 未訪問のキュー（[座標文字列, 距離]の配列）
    @queue = []

    # 開始地点を設定
    @start = koshien.position(@my_x, @my_y)
    @goal = koshien.position(@goal_x, @goal_y)
    @distances[@start] = 0
    @queue.push([@start, 0])

    # ダイクストラ法のメインループ
    while @queue.length > 0
      # 距離が最小のノードを取得
      @queue.sort_by! { |a| a[1] }
      @current = @queue.shift
      @current_pos = @current[0]
      @current_dist = @current[1]

      # ゴールに到達したら終了
      break if @current_pos == @goal

      # 現在位置の座標を取得
      @curr_x = koshien.position_of_x(@current_pos)
      @curr_y = koshien.position_of_y(@current_pos)

      # 4方向（上下左右）をチェック
      [
        [@curr_x, @curr_y - 1], # 上
        [@curr_x, @curr_y + 1], # 下
        [@curr_x - 1, @curr_y], # 左
        [@curr_x + 1, @curr_y]  # 右
      ].each do |neighbor_coords|
        @nx = neighbor_coords[0]
        @ny = neighbor_coords[1]

        # マップ範囲外チェック
        next if @nx < 0 || @nx >= 15 || @ny < 0 || @ny >= 15

        @neighbor = koshien.position(@nx, @ny)

        # 通らない座標かチェック
        @skip = false
        list("$通らない座標").each do |avoid_pos|
          if @neighbor == avoid_pos
            @skip = true
            break
          end
        end
        next if @skip

        # map_from でマップ情報を取得
        @cell_value = koshien.map_from(@neighbor, @map_snapshot)

        # 移動可能かチェック（空間=0, 水たまり=4, ゴール=3のみ移動可能）
        next if @cell_value != 0 && @cell_value != 4 && @cell_value != 3

        # 新しい距離を計算
        @new_dist = @current_dist + 1

        # より短い経路が見つかった場合
        if !@distances[@neighbor] || @new_dist < @distances[@neighbor]
          @distances[@neighbor] = @new_dist
          @previous[@neighbor] = @current_pos
          @queue.push([@neighbor, @new_dist])
        end
      end
    end

    # ゴールから逆順に経路を構築
    if @previous[@goal]
      @path_pos = @goal
      @path = [@goal]
      while @previous[@path_pos] && @previous[@path_pos] != @start
        @path_pos = @previous[@path_pos]
        @path.unshift(@path_pos)
      end
      @path.unshift(@start)

      # 最短経路リストに保存
      @path.each do |pos|
        list("$最短経路").push(pos)
      end

      # 次の移動先をメッセージ表示
      if list("$最短経路").length > 2
        @next_pos = list("$最短経路")[2]
        @next_value = koshien.map_from(@next_pos, @map_snapshot)
        koshien.set_message("次:" + @next_pos.to_s + " 値:" + @next_value.to_s)
      end
    else
      # 経路が見つからない場合は現在地のみ
      list("$最短経路").push(@start)
      koshien.set_message("経路なし")
    end
  end

  def self.最短経路を進む
    if list("$最短経路").length > 2
      koshien.move_to(list("$最短経路")[2])
      @action_count += 1
    end
  end

  def self.マップ情報を取得する(position)
    koshien.get_map_area(position)
    @action_count += 1

    簡易ダイクストラ法で最短経路を計算
  end

  def self.ターン終了
    koshien.turn_over
    @turn_count += 1
    @action_count = 0
  end

  koshien.connect_game(name: "map_all")

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
      # 毎ターン現在地を探索してマップを更新
      マップ情報を取得する(koshien.player)
    end

    if @action_count < 2
      最短経路を進む
    end

    ターン終了
  end
end
