class Enemy < ApplicationRecord
  belongs_to :game_round

  validates :position_x, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :position_y, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :hp, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :attack_power, presence: true, numericality: {greater_than_or_equal_to: 0}

  def position
    {x: position_x, y: position_y}
  end

  def alive?
    hp > 0
  end

  def defeated?
    hp <= 0
  end
end
