class PushSubscription < ApplicationRecord
  belongs_to :user

  # Validations
  validates :endpoint, presence: true, uniqueness: true,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                     message: "must be a valid URL" }
  validates :p256dh_key, presence: true,
            format: { with: /\A[A-Za-z0-9_-]+\z/, message: "must be valid base64url" }
  validates :auth_key, presence: true,
            format: { with: /\A[A-Za-z0-9_-]+\z/, message: "must be valid base64url" }
  validates :user_agent, length: { maximum: 500 }, allow_nil: true

  # Scopes
  scope :stale, ->(days = 90) { where("updated_at < ?", days.days.ago) }

  # Touch updated_at when subscription is verified as working
  def mark_as_active!
    touch
  end

  # Class method for cleanup
  def self.cleanup_stale(days = 90)
    stale(days).destroy_all
  end
end
