class PlayerAi < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 10000 }
  validates :author, length: { maximum: 100 }

  scope :available, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :preset, -> { where(author: 'system') }

  before_create :set_expiration

  def expired?
    expires_at <= Time.current
  end

  def preset?
    author == 'system'
  end

  private

  def set_expiration
    # プリセットAI以外は2日後に削除
    self.expires_at = preset? ? 1.year.from_now : 2.days.from_now
  end
end
