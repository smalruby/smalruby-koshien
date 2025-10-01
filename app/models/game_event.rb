class GameEvent < ApplicationRecord
  belongs_to :game_turn
  belongs_to :player, optional: true

  validates :event_type, presence: true
  validate :event_data_format

  private

  def event_data_format
    if event_data.nil?
      errors.add(:event_data, "can't be blank")
    elsif !event_data.is_a?(Hash)
      errors.add(:event_data, "must be a hash")
    end
  end

  public

  # イベントタイプの定数定義
  PLAYER_MOVE = "player_move".freeze
  ITEM_COLLECT = "item_collect".freeze
  ENEMY_ENCOUNTER = "enemy_encounter".freeze
  GAME_END = "game_end".freeze

  # TurnProcessor で使用される追加のイベントタイプ
  AI_TIMEOUT = "AI_TIMEOUT".freeze
  WAIT = "WAIT".freeze
  MOVE = "MOVE".freeze
  MOVE_BLOCKED = "MOVE_BLOCKED".freeze
  USE_DYNAMITE = "USE_DYNAMITE".freeze
  USE_DYNAMITE_FAILED = "USE_DYNAMITE_FAILED".freeze
  USE_BOMB = "USE_BOMB".freeze
  USE_BOMB_FAILED = "USE_BOMB_FAILED".freeze
  PLAYER_COLLISION = "PLAYER_COLLISION".freeze
  COLLECT_ITEM = "COLLECT_ITEM".freeze
  HIT_TRAP = "HIT_TRAP".freeze
  ENEMY_ATTACK = "ENEMY_ATTACK".freeze
  WALK_BONUS = "WALK_BONUS".freeze
  EXPLORE = "EXPLORE".freeze
  SET_DYNAMITE = "SET_DYNAMITE".freeze
  SET_DYNAMITE_FAILED = "SET_DYNAMITE_FAILED".freeze
  SET_BOMB = "SET_BOMB".freeze
  SET_BOMB_FAILED = "SET_BOMB_FAILED".freeze
  EXPLOSION = "EXPLOSION".freeze
  WALL_DESTROYED = "WALL_DESTROYED".freeze

  EVENT_TYPES = [
    PLAYER_MOVE,
    ITEM_COLLECT,
    ENEMY_ENCOUNTER,
    GAME_END,
    AI_TIMEOUT,
    WAIT,
    MOVE,
    MOVE_BLOCKED,
    USE_DYNAMITE,
    USE_DYNAMITE_FAILED,
    USE_BOMB,
    USE_BOMB_FAILED,
    PLAYER_COLLISION,
    COLLECT_ITEM,
    HIT_TRAP,
    ENEMY_ATTACK,
    WALK_BONUS,
    EXPLORE,
    SET_DYNAMITE,
    SET_DYNAMITE_FAILED,
    SET_BOMB,
    SET_BOMB_FAILED,
    EXPLOSION,
    WALL_DESTROYED
  ].freeze

  validates :event_type, inclusion: {in: EVENT_TYPES}

  # イベントデータをJSONとしてシリアライズ
  serialize :event_data, coder: JSON

  scope :by_type, ->(type) { where(event_type: type) }
  scope :ordered, -> { joins(:game_turn).order("game_turns.turn_number ASC, created_at ASC") }
end
