class GameMap < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :map_data, presence: true
  validates :goal_position, presence: true

  serialize :map_data, coder: JSON
  serialize :map_height, coder: JSON
  serialize :goal_position, coder: JSON

  def size
    {
      width: map_data.first&.size || 0,
      height: map_data.size
    }
  end

  def goal_position_object
    goal_position.symbolize_keys if goal_position.is_a?(Hash)
  end

  def self.preset_maps
    where(name: %w[map1 map2 map3 map4 map5 map6 map7 map8 map9 map10])
  end
end
