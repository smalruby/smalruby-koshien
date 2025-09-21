class Game < ApplicationRecord
  belongs_to :first_player_ai, class_name: 'PlayerAi'
  belongs_to :second_player_ai, class_name: 'PlayerAi'
  belongs_to :game_map

  enum :status, {
    waiting_for_players: 0,
    in_progress: 1,
    completed: 2,
    cancelled: 3
  }

  enum :winner, {
    first: 0,
    second: 1
  }, prefix: true

  validates :battle_url, presence: true, on: :create

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [:waiting_for_players, :in_progress]) }

  def finished?
    completed? || cancelled?
  end

  def player_ais
    [first_player_ai, second_player_ai]
  end

  def winner_ai
    return nil unless finished? && winner.present?
    winner_first? ? first_player_ai : second_player_ai
  end

  def loser_ai
    return nil unless finished? && winner.present?
    winner_first? ? second_player_ai : first_player_ai
  end

  def generate_battle_url
    # バトルURL生成ロジック（後で実装）
    self.battle_url = "https://koshien.smalruby.app/battles/#{id}"
  end
end
