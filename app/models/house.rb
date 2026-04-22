class House < ApplicationRecord
  SHARE_TOKEN_BYTES = 24 # SecureRandom.urlsafe_base64(24) => 32 chars

  has_many :ratings, dependent: :destroy

  validates :alias_name,       presence: true
  validates :owner_session_id, presence: true
  validates :share_token,      presence: true, uniqueness: true

  before_validation :ensure_share_token

  scope :for_owner, ->(owner_id) { where(owner_session_id: owner_id) }

  def regenerate_share_token!
    update!(share_token: self.class.generate_share_token)
  end

  def self.generate_share_token
    SecureRandom.urlsafe_base64(SHARE_TOKEN_BYTES)
  end

  private

  def ensure_share_token
    self.share_token ||= self.class.generate_share_token
  end
end
