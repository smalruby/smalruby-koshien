class PlayerAi < ApplicationRecord
  # アソシエーション
  has_many :first_player_games, class_name: "Game", foreign_key: "first_player_ai_id", dependent: :nullify
  has_many :second_player_games, class_name: "Game", foreign_key: "second_player_ai_id", dependent: :nullify

  # バリデーション
  validates :name, presence: true, length: {maximum: 100}, uniqueness: true
  validates :code, presence: true, length: {maximum: 10000}
  validates :author, length: {maximum: 100}

  scope :available, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :preset, -> { where(author: "system") }

  before_create :set_expiration

  def expired?
    expires_at <= Time.current
  end

  def preset?
    author == "system"
  end

  private

  def set_expiration
    # プリセットAI以外は2日後に削除
    self.expires_at = preset? ? 1.year.from_now : 2.days.from_now
  end
end
