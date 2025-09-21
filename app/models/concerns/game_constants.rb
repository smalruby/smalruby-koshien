module GameConstants
  extend ActiveSupport::Concern

  # ゲーム設定定数
  N_PLAYERS = 2
  N_ROUNDS = 2
  TURN_DURATION = 10
  MAX_TURN = 50
  MAX_GOAL_BONUS = 100
  ENEMY_DISCOUNT = -10
  ENEMY_ATTACK_BONUS = 30

  # マップチップ番号
  MAP_BLANK = 0
  MAP_WALL1 = 1
  MAP_WALL2 = 2
  MAP_GOAL = 3
  MAP_WATER = 4
  MAP_BREAKABLE_WALL = 5

  # アイテム関連
  ITEM_SORD = 5
  ITEM_SCORES = [0, 10, 20, 30, 40, 60, -10, -20, -30, -40].freeze
  ITEM_MARKS = [nil, "a", "b", "c", "d", "e", "A", "B", "C", "D"].freeze
  ITEM_BLANK_INDEX = 0
  DYNAMITE_ITEM_INDEX = 10
  BOMB_ITEM_INDEX = 9

  # アイテム配置数
  ITEM_QUANTITIES = {
    1 => 3,
    2 => 2,
    3 => 2,
    4 => 2,
    5 => 2,
    6 => 2,
    7 => 2,
    8 => 2,
    9 => 2
  }.freeze

  # プレイヤー設定
  WALK_BONUS = 3
  WALK_BONUS_BOUNDARY = 5
  LATEST_SEARCH_LEVEL = 5
  N_DYNAMITE = 2
  N_BOMB = 2

  # Enemy設定
  ANGRY_TURN = 41

  # 爆発方向
  RIGHT_SIDE = 1
  LEFT_SIDE = -1
  UP_SIDE = 1
  DOWN_SIDE = -1
end
