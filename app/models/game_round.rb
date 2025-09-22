class GameRound < ApplicationRecord
  belongs_to :game

  has_many :players, dependent: :destroy
  has_many :enemies, dependent: :destroy
  has_many :game_turns, dependent: :destroy

  serialize :item_locations, coder: JSON

  validates :round_number, presence: true, uniqueness: {scope: :game_id}
  validates :status, presence: true
  validate :item_locations_format

  private

  def item_locations_format
    if item_locations.nil?
      errors.add(:item_locations, "can't be blank")
    elsif !item_locations.is_a?(Hash)
      errors.add(:item_locations, "must be a hash")
    end
  end

  public

  enum :status, {
    preparing: 0,
    in_progress: 1,
    finished: 2
  }

  enum :winner, {
    no_winner: 0,
    player1: 1,
    player2: 2,
    draw: 3
  }

  scope :by_round_number, ->(number) { where(round_number: number) }
  scope :finished_rounds, -> { where(status: :finished) }
end
