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

  # 敵の移動ロジック（第1段階：ランダム移動のみ）
  def move(game_map_data, players)
    return unless position_x && position_y

    # 前の位置を記録
    self.previous_position_x = position_x
    self.previous_position_y = position_y

    # プレイヤーが射程外の場合はランダム移動
    target_player = find_player_in_range(players)
    if target_player.nil?
      move_randomly(game_map_data)
    else
      # TODO: 後の段階で実装
      Rails.logger.debug "Enemy found player in range, but movement logic not implemented yet"
    end
  end

  private

  # 射程内のプレイヤーを探す（第1段階では基本実装のみ）
  def find_player_in_range(players)
    players.each do |player|
      # プレイヤーが終了している場合はスキップ
      next if player_finished?(player)

      # 射程判定（3マス以内）
      dx = (position_x - player.position_x).abs
      dy = (position_y - player.position_y).abs
      if dx <= 3 && dy <= 3
        return player
      end
    end
    nil
  end

  # プレイヤーが終了しているかチェック
  def player_finished?(player)
    # TODO: プレイヤーのステータスに基づく判定を実装
    false
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
