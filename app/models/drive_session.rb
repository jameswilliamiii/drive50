class DriveSession < ApplicationRecord
  belongs_to :user

  # Validations
  validates :driver_name, presence: true
  validates :started_at, presence: true
  validate :ended_at_after_started_at, if: -> { ended_at.present? }

  # Scopes
  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }
  scope :night_drives, -> { where(is_night_drive: true) }
  scope :ordered, -> { order(started_at: :desc) }

  # Callbacks
  before_save :calculate_duration, if: -> { ended_at.present? && ended_at_changed? }
  before_save :determine_night_drive, if: -> { started_at_changed? || ended_at_changed? }

  # Class methods
  def self.total_hours
    completed.sum(:duration_minutes) / 60.0
  end

  def self.night_hours
    night_drives.completed.sum(:duration_minutes) / 60.0
  end

  def self.hours_needed
    [ 50 - total_hours, 0 ].max
  end

  def self.night_hours_needed
    [ 10 - night_hours, 0 ].max
  end

  # Instance methods
  def completed?
    ended_at.present?
  end

  def in_progress?
    !completed?
  end

  def duration_hours
    return 0 unless duration_minutes
    (duration_minutes / 60.0).round(2)
  end

  private

  def ended_at_after_started_at
    if ended_at <= started_at
      errors.add(:ended_at, "must be after start time")
    end
  end

  def calculate_duration
    return unless started_at && ended_at
    self.duration_minutes = ((ended_at - started_at) / 60).to_i
  end

  def determine_night_drive
    return unless started_at

    # Simple heuristic: 8pm - 6am is night
    # For production, could use sunrise/sunset API
    hour = started_at.hour
    self.is_night_drive = hour >= 20 || hour < 6
  end
end
