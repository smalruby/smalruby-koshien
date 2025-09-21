class GameEvent < ApplicationRecord
  belongs_to :game_turn

  validates :event_type, presence: true
  validates :event_data, presence: true

  # イベントタイプの定数定義
  PLAYER_MOVE = "player_move".freeze
  ITEM_COLLECT = "item_collect".freeze
  ENEMY_ENCOUNTER = "enemy_encounter".freeze
  GAME_END = "game_end".freeze

  EVENT_TYPES = [
    PLAYER_MOVE,
    ITEM_COLLECT,
    ENEMY_ENCOUNTER,
    GAME_END
  ].freeze

  validates :event_type, inclusion: {in: EVENT_TYPES}

  # イベントデータをJSONとしてシリアライズ
  serialize :event_data, coder: JSON

  scope :by_type, ->(type) { where(event_type: type) }
  scope :ordered, -> { joins(:game_turn).order("game_turns.turn_number ASC, created_at ASC") }
end
