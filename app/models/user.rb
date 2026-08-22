class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :drive_sessions, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  # Also the number field's `max:` in the registration and settings forms.
  MAX_HOURS_GOAL = 1000

  # Central time, not a UTC that describes nobody — what a driver with no
  # timezone yet (new signup, detection hasn't posted back) is judged against.
  DEFAULT_TIMEZONE = "America/Chicago"

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :hours_goal, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_HOURS_GOAL }
  validates :night_hours_goal, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_HOURS_GOAL }
  validates :night_hours_goal, numericality: { less_than_or_equal_to: :hours_goal, message: "can't be more than the total hours goal" },
                                if: -> { hours_goal.present? && night_hours_goal.present? }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def password_reset_token
    signed_id(expires_in: 1.hour, purpose: :password_reset)
  end

  def self.find_by_password_reset_token!(token)
    find_signed!(token, purpose: :password_reset)
  end
end
