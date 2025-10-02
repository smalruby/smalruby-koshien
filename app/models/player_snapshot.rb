class PlayerSnapshot < ApplicationRecord
  belongs_to :game_turn
  belongs_to :player

  serialize :my_map, coder: JSON
  serialize :map_fov, coder: JSON

  enum :status, {
    playing: 0,
    completed: 1,
    timeout: 2,
    timeup: 3
  }

  validates :position_x, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :position_y, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :score, presence: true, numericality: true
  validates :dynamite_left, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :bomb_left, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :character_level, presence: true, numericality: {greater_than_or_equal_to: 1}
  validates :walk_bonus_counter, presence: true, numericality: {greater_than_or_equal_to: 0}

  def position
    [position_x, position_y]
  end

  def previous_position
    [previous_position_x, previous_position_y]
  end
end
