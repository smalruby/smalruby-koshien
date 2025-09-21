class GameMap < ApplicationRecord
  # アソシエーション
  has_many :games, dependent: :restrict_with_error

  # バリデーション
  validates :name, presence: true, length: {maximum: 100}, uniqueness: true
  validates :map_data, presence: true
  validates :goal_position, presence: true
  validate :validate_map_data_format
  validate :validate_goal_position_format

  serialize :map_data, coder: JSON
  serialize :map_height, coder: JSON
  serialize :goal_position, coder: JSON

  has_one_attached :thumbnail

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

  private

  def validate_map_data_format
    return unless map_data.present?

    unless map_data.is_a?(Array) && map_data.all? { |row| row.is_a?(Array) }
      errors.add(:map_data, "must be a 2D array")
    end
  end

  def validate_goal_position_format
    return unless goal_position.present?

    unless goal_position.is_a?(Hash) && goal_position.key?("x") && goal_position.key?("y")
      errors.add(:goal_position, "must be a hash with x and y keys")
    end
  end
end
