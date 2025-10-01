class Player < ApplicationRecord
  include GameConstants

  belongs_to :game_round
  belongs_to :player_ai

  validates :position_x, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :position_y, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :score, presence: true, numericality: true
  validates :dynamite_left, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :bomb_left, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :character_level, presence: true, numericality: {greater_than_or_equal_to: 1}
  validates :walk_bonus_counter, presence: true, numericality: {greater_than_or_equal_to: 0}

  serialize :my_map, coder: JSON
  serialize :map_fov, coder: JSON

  enum :status, {
    playing: 0,
    completed: 1,
    timeout: 2,
    timeup: 3
  }

  scope :active_players, -> { where(status: :playing) }
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

  def can_use_bomb?
    bomb_left > 0
  end

  def use_bomb
    return false unless can_use_bomb?

    self.bomb_left -= 1
    true
  end

  def calc_character_level(total_score = nil)
    score_to_calc = total_score || score
    [(score_to_calc - 1).div(20), 0].max.clamp(1, 8)
  end

  def update_character_level
    return unless playing?

    new_level = calc_character_level
    self.character_level = new_level
  end

  def get_positive_item(item_idx)
    return unless acquired_positive_items.is_a?(Array) && item_idx.between?(1, 5)

    current_items = acquired_positive_items.dup
    current_items[item_idx] += 1
    self.acquired_positive_items = current_items
  end

  def calc_walk_bonus_with_counter
    return false unless has_moved?

    self.walk_bonus_counter += 1

    if walk_bonus_counter >= WALK_BONUS_BOUNDARY
      self.score += WALK_BONUS
      self.walk_bonus_counter = 0
      self.walk_bonus = true
      true
    else
      false
    end
  end

  def finished?
    completed? || timeout? || timeup?
  end

  def encount_enemy?(enemy_info)
    [position_x, position_y] == [enemy_info[:x].to_i, enemy_info[:y].to_i]
  end

  def update_my_map!(rng_x, rng_y, map_snapshot)
    # Update player's personal map with snapshot data for the specified range
    # Deep clone to ensure Rails detects changes
    current_my_map = my_map.map(&:dup)
    current_map_fov = map_fov.map(&:dup)

    Rails.logger.info "🗺️ Updating my_map for player #{id} at range x=#{rng_x.inspect}, y=#{rng_y.inspect}"
    Rails.logger.info "🗺️ Map snapshot: #{map_snapshot.inspect}"
    Rails.logger.info "🗺️ Before: my_map[#{rng_y.first}][#{rng_x.first}] = #{current_my_map[rng_y.first][rng_x.first]}"

    rng_y.each_with_index do |my_map_y, y_pos|
      rng_x.each_with_index do |my_map_x, x_pos|
        current_my_map[my_map_y][my_map_x] = map_snapshot[y_pos][x_pos]
      end
    end

    # Mark explored cells with LATEST_SEARCH_LEVEL in field of view
    rng_y.each do |my_map_y|
      rng_x.each do |my_map_x|
        current_map_fov[my_map_y][my_map_x] = LATEST_SEARCH_LEVEL
      end
    end

    self.my_map = current_my_map
    self.map_fov = current_map_fov

    save!

    Rails.logger.info "🗺️ After save: my_map[#{rng_y.first}][#{rng_x.first}] = #{my_map[rng_y.first][rng_x.first]}"
  end

  def api_info
    {
      id: id,
      x: position_x,
      y: position_y,
      prev_x: previous_position_x,
      prev_y: previous_position_y,
      score: score,
      character_level: character_level,
      dynamite_left: dynamite_left,
      bomb_left: bomb_left,
      walk_bonus_counter: walk_bonus_counter,
      acquired_positive_items: acquired_positive_items,
      status: status,
      has_goal_bonus: has_goal_bonus?,
      walk_bonus: walk_bonus?
    }
  end
end
