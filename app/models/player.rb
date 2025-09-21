class Player < ApplicationRecord
  belongs_to :game_round
  belongs_to :player_ai

  validates :position_x, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :position_y, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :score, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :dynamite_left, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :character_level, presence: true, numericality: {greater_than_or_equal_to: 1}

  enum :status, {
    active: 0,
    inactive: 1,
    defeated: 2
  }

  scope :active_players, -> { where(status: :active) }
  scope :by_position, ->(x, y) { where(position_x: x, position_y: y) }

  def position
    [position_x, position_y]
  end

  def previous_position
    [previous_position_x, previous_position_y]
  end

  def move_to(x, y)
    self.previous_position_x = position_x
    self.previous_position_y = position_y
    self.position_x = x
    self.position_y = y
  end

  def has_moved?
    position_x != previous_position_x || position_y != previous_position_y
  end

  def can_use_dynamite?
    dynamite_left > 0
  end

  def use_dynamite
    return false unless can_use_dynamite?

    self.dynamite_left -= 1
    true
  end

  def apply_goal_bonus
    return false if has_goal_bonus?

    self.has_goal_bonus = true
    self.score += 100 # ゴールボーナス
    true
  end

  def apply_walk_bonus
    return false if walk_bonus? || !has_moved?

    self.walk_bonus = true
    self.score += 1 # 歩行ボーナス
    true
  end
end
