class GameTurn < ApplicationRecord
  belongs_to :game_round
  has_many :game_events, dependent: :destroy
  has_many :player_snapshots, dependent: :destroy

  validates :turn_number, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :turn_finished, inclusion: {in: [true, false]}

  scope :finished, -> { where(turn_finished: true) }
  scope :unfinished, -> { where(turn_finished: false) }
  scope :ordered, -> { order(:turn_number) }

  # Delegate players access to game_round
  # This provides a convenient way to access players for this turn
  delegate :players, to: :game_round
end
