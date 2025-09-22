class Enemy < ApplicationRecord
  include GameConstants

  belongs_to :game_round

  validates :position_x, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :position_y, presence: true, numericality: {greater_than_or_equal_to: 0}

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
    angry?
  end

  def kill?
    kill?
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
end
