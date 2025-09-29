class Enemy < ApplicationRecord
  include GameConstants

  belongs_to :game_round

  validates :position_x, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :position_y, presence: true, numericality: {greater_than_or_equal_to: 0}

  # 敵が移動可能なマップチップ
  MOVABLE_CHIPS = [MAP_BLANK, MAP_WATER, MAP_GOAL].freeze
  # 怒りモードになるターン
  ANGRY_TURN = 41

  enum :state, {
    normal_state: 0,
    angry: 1,
    kill: 2,
    done: 3
  }

  enum :enemy_kill, {
    no_kill: 0,
    player1_kill: 1,
    player2_kill: 2,
    both_kill: 3,
    kill_done: 4
  }

  def position
    {x: position_x, y: position_y}
  end

  def api_info
    {
      x: position_x,
      y: position_y,
      prev_x: previous_position_x,
      prev_y: previous_position_y,
      state: state,
      kill_player: enemy_kill,
      killed: killed
    }
  end

  def angry?
    state == "angry"
  end

  def kill?
    state == "kill"
  end

  def normal?
    normal_state?
  end

  def killed?
    killed
  end

  def can_attack?(player_id)
    both_kill? ||
      (player_id == 0 && player1_kill?) ||
      (player_id == 1 && player2_kill?)
  end

  def raise_kill
    # オロチ撃退モードフラグを上げる処理
    # 実装は競技サーバーのロジックに基づく
  end

  def lower_kill
    # オロチ撃退モードフラグを下げる処理
    # 実装は競技サーバーのロジックに基づく
  end

  # 敵の移動ロジック（全段階実装）
  def move(game_map_data, players)
    return unless position_x && position_y

    # 前の位置を記録
    self.previous_position_x = position_x
    self.previous_position_y = position_y

    # プレイヤーが射程内にいるかチェック
    target_player = find_player_in_range(players)
    if target_player.nil?
      # 第1段階：射程外の場合はランダム移動
      move_randomly(game_map_data)
    elsif too_close_to_player?(target_player)
      # 第3段階：隣接している場合は移動しない
      Rails.logger.debug "Enemy too close to player, staying at (#{position_x}, #{position_y})"
    else
      # 第2段階：射程内だが隣接していない場合はプレイヤーに接近
      move_towards_player(game_map_data, target_player)
    end
  end

  private

  # 射程内のプレイヤーを探す（参考実装に基づく完全版）
  def find_player_in_range(players)
    candidates = []

    players.each do |player|
      # プレイヤーが終了している場合はスキップ
      next if player_finished?(player)

      # 射程判定（3マス以内）
      dx = (position_x - player.position_x).abs
      dy = (position_y - player.position_y).abs
      if dx <= 3 && dy <= 3
        # ユークリッド距離を計算
        distance = Math.sqrt(dx**2 + dy**2)
        candidates << [player, distance]
      end
    end

    case candidates.length
    when 0
      nil
    when 1
      candidates.first[0]
    else
      # 複数のプレイヤーが射程内にいる場合
      if candidates.all? { |_, d| d == candidates.first[1] }
        # 距離が同じ場合はラウンドによって対象を変える（公平性のため）
        # TODO: 現在のラウンドを取得する仕組みが必要
        candidates[0][0]  # 暫定的に最初のプレイヤーを選択
      else
        # 最も近いプレイヤーを選択
        candidates.min_by { |_, distance| distance }[0]
      end
    end
  end

  # プレイヤーが終了しているかチェック
  def player_finished?(player)
    # プレイヤーのステータスがplayingでない場合は終了とみなす
    player.status != "playing"
  end

  # プレイヤーに隣接しているかチェック（マンハッタン距離1以下）
  def too_close_to_player?(player)
    dx = (position_x - player.position_x).abs
    dy = (position_y - player.position_y).abs
    (dx + dy) <= 1
  end

  # プレイヤーに向かって移動（第2段階の実装）
  def move_towards_player(game_map_data, player)
    require_relative "../../lib/dijkstra_search"

    begin
      # Dijkstra探索用のグラフデータを作成
      graph_data = make_graph_data(game_map_data)
      graph = DijkstraSearch::Graph.new(graph_data)

      # 現在位置と目標位置のID
      start_id = "m#{position_x}_#{position_y}"
      goal_id = "m#{player.position_x}_#{player.position_y}"

      # 最短経路を取得
      routes = graph.get_route(start_id, goal_id)
      routes.shift  # 始点を取り除く

      # 2歩以内の場合は移動しない（プレイヤーから距離を保つ）
      if routes.size > 2
        next_x, next_y = routes.first
        self.position_x = next_x
        self.position_y = next_y
        Rails.logger.debug "Enemy moved towards player from (#{previous_position_x}, #{previous_position_y}) to (#{position_x}, #{position_y})"
      else
        Rails.logger.debug "Enemy close enough to player, not moving"
      end
    rescue => e
      Rails.logger.error "Enemy pathfinding error: #{e.message}, falling back to random movement"
      move_randomly(game_map_data)
    end
  end

  # DijkstraSearch用のグラフデータを作成
  def make_graph_data(game_map_data)
    data = {}

    game_map_data.each_with_index do |row, y|
      row.each_with_index do |cell, x|
        edges = []

        # 上下左右の隣接セルをチェック
        [[x, y - 1], [x, y + 1], [x - 1, y], [x + 1, y]].each do |nx, ny|
          next if nx < 0 || ny < 0
          next if ny >= game_map_data.length || nx >= game_map_data[ny].length

          # 移動可能なセルの場合は辺として追加
          if MOVABLE_CHIPS.include?(game_map_data[ny][nx])
            edges << [1, "m#{nx}_#{ny}"]  # コスト1で隣接セルに移動
          end
        end

        data["m#{x}_#{y}"] = edges
      end
    end

    data
  end

  # ランダムに1歩移動
  def move_randomly(game_map_data)
    available_cells = []

    # 上
    if position_y > 0 && can_move_to?(game_map_data, position_x, position_y - 1)
      available_cells << [position_x, position_y - 1]
    end

    # 下
    if position_y < game_map_data.length - 1 && can_move_to?(game_map_data, position_x, position_y + 1)
      available_cells << [position_x, position_y + 1]
    end

    # 左
    if position_x > 0 && can_move_to?(game_map_data, position_x - 1, position_y)
      available_cells << [position_x - 1, position_y]
    end

    # 右
    if position_x < game_map_data[0].length - 1 && can_move_to?(game_map_data, position_x + 1, position_y)
      available_cells << [position_x + 1, position_y]
    end

    # 移動可能なセルがある場合はランダムに選択
    if available_cells.any?
      new_x, new_y = available_cells.sample
      self.position_x = new_x
      self.position_y = new_y
      Rails.logger.debug "Enemy moved randomly from (#{previous_position_x}, #{previous_position_y}) to (#{position_x}, #{position_y})"
    else
      Rails.logger.debug "Enemy has no available moves, staying at (#{position_x}, #{position_y})"
    end
  end

  # 指定位置に移動可能かチェック
  def can_move_to?(game_map_data, x, y)
    return false if x < 0 || y < 0
    return false if y >= game_map_data.length || x >= game_map_data[y].length

    chip_value = game_map_data[y][x]
    MOVABLE_CHIPS.include?(chip_value)
  end
end
