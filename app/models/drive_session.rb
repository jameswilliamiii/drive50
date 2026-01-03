require "solareventcalculator"

class DriveSession < ApplicationRecord
  include DriveSessionStatistics

  HOURS_NEEDED = 50
  NIGHT_HOURS_NEEDED = 10
  ACTIVITY_CALENDAR_DAYS = 28

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
  after_create_commit :broadcast_create
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_destroy

  # Class methods
  def self.total_hours
    completed.sum(:duration_minutes) / 60.0
  end

  def self.night_hours
    night_drives.completed.sum(:duration_minutes) / 60.0
  end

  def self.hours_needed
    [ HOURS_NEEDED - total_hours, 0 ].max
  end

  def self.night_hours_needed
    [ NIGHT_HOURS_NEEDED - night_hours, 0 ].max
  end

  def self.activity_by_date(days: ACTIVITY_CALENDAR_DAYS, timezone: "UTC")
    # Calculate date range in user's timezone
    end_date = Time.current.in_time_zone(timezone).to_date
    start_date = end_date - (days - 1).days

    completed
      .where("started_at >= ?", start_date.beginning_of_day.in_time_zone(timezone))
      .group_by { |session| session.started_at.in_time_zone(timezone).to_date }
      .transform_values(&:count)
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

  def elapsed_time
    return nil unless in_progress? && started_at
    elapsed_seconds = (Time.current - started_at).to_i
    hours = elapsed_seconds / 3600
    minutes = (elapsed_seconds % 3600) / 60

    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
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

    user_timezone = user.timezone || "UTC"
    local_start = started_at.in_time_zone(user_timezone)

    coords = if user.latitude.present? && user.longitude.present?
      { lat: user.latitude.to_f, lon: user.longitude.to_f }
    else
      TimezoneCoordinates.coordinates_for_timezone(user_timezone)
    end

    started_at_night = night_time?(local_start, coords[:lat], coords[:lon])

    if ended_at.present?
      local_end = ended_at.in_time_zone(user_timezone)
      ended_at_night = night_time?(local_end, coords[:lat], coords[:lon])
      self.is_night_drive = started_at_night || ended_at_night
    else
      self.is_night_drive = started_at_night
    end
  end

  def night_time?(time, latitude, longitude)
    local_date = time.to_date
    solar_event = SolarEventCalculator.new(local_date, latitude, longitude)
    sunrise_utc = solar_event.compute_utc_civil_sunrise
    sunset_utc = solar_event.compute_utc_civil_sunset

    return false if sunrise_utc.nil? || sunset_utc.nil?

    time_utc = time.utc.to_datetime
    time_utc < sunrise_utc || time_utc > sunset_utc
  end

  def broadcast_create
    if completed?
      broadcast_recent_drives_table
      broadcast_append_to user, target: "sessions-tbody", html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
    else
      broadcast_replace_to user, target: "in-progress-drive", html: ApplicationController.render(partial: "drive_sessions/in_progress_drive", locals: { in_progress: self })
    end
    broadcast_progress_summary
  end

  def broadcast_update
    if completed?
      was_in_progress = saved_change_to_ended_at? && ended_at.present? && ended_at_before_last_save.nil?

      if was_in_progress
        broadcast_remove_to user, target: "in-progress-drive"
        broadcast_append_to user, target: "sessions-tbody", html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
      else
        broadcast_replace_to user, target: ActionView::RecordIdentifier.dom_id(self), html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
      end

      broadcast_recent_drives_table
    else
      broadcast_replace_to user, target: "in-progress-drive", html: ApplicationController.render(partial: "drive_sessions/in_progress_drive", locals: { in_progress: self })
    end
    broadcast_progress_summary
  end

  def broadcast_destroy
    broadcast_remove_to user, target: ActionView::RecordIdentifier.dom_id(self)
    broadcast_recent_drives_table
    broadcast_progress_summary
  end

  def broadcast_recent_drives_table
    recent_sessions = user.drive_sessions.completed.ordered.limit(3)
    broadcast_replace_to user, target: "recent-drives-table", html: ApplicationController.render(partial: "drive_sessions/recent_drives_table", locals: { recent_sessions: recent_sessions })
  end

  def broadcast_progress_summary
    user.association(:drive_sessions).reset
    relation = user.drive_sessions

    statistics = DriveSession.statistics_for(relation)
    in_progress = statistics[:in_progress]

    activity_data = relation.activity_by_date(days: ACTIVITY_CALENDAR_DAYS, timezone: user.timezone || "UTC")

    broadcast_replace_to user,
                         target: "progress-summary",
                         html: ApplicationController.render(
                           partial: "drive_sessions/progress_summary",
                           locals: {
                             in_progress: in_progress,
                             total_hours: statistics[:total_hours],
                             night_hours: statistics[:night_hours],
                             activity_calendar: ApplicationController.helpers.activity_calendar_data(activity_data, timezone: user.timezone || "UTC")
                           }
                         )

    broadcast_update_to user,
                        target: "in-progress-banner-container",
                        html: ApplicationController.render(
                          partial: "shared/in_progress_banner",
                          locals: { in_progress: in_progress }
                        )

    broadcast_update_to user,
                        target: "fab-new-drive-wrapper",
                        html: ApplicationController.render(
                          partial: "shared/fab_new_drive",
                          locals: { in_progress: in_progress }
                        )
  end
end
