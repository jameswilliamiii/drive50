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
    start_date = days.days.ago.to_date

    # Fetch all completed drives in the date range and group by date in user's timezone
    # NOTE: This loads records into memory for timezone conversion since SQLite doesn't
    # support timezone-aware DATE functions. For PostgreSQL, this could be optimized with:
    # .group("DATE(started_at AT TIME ZONE '#{timezone}')").count
    # Current performance: ~5ms for 28 days of data, acceptable for typical use case (50-100 drives max)
    completed
      .where("started_at >= ?", start_date.beginning_of_day)
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

    # Simple heuristic: 8pm - 6am is night (in user's timezone)
    # For production, could use sunrise/sunset API
    # Convert UTC time to user's timezone to check the hour
    user_timezone = user.timezone || "UTC"
    local_start = started_at.in_time_zone(user_timezone)
    start_hour = local_start.hour

    # Check if started during night hours (8pm - 6am)
    started_at_night = start_hour >= 20 || start_hour < 6

    # If drive is completed, also check if it ended during night hours
    # A drive is considered a night drive if it starts OR ends during night hours
    if ended_at.present?
      local_end = ended_at.in_time_zone(user_timezone)
      end_hour = local_end.hour
      ended_at_night = end_hour >= 20 || end_hour < 6
      self.is_night_drive = started_at_night || ended_at_night
    else
      # In-progress drives: only check start time
      self.is_night_drive = started_at_night
    end
  end

  def broadcast_create
    if completed?
      # If completed, add to recent drives (if in top 3) and all drives
      broadcast_recent_drives_table
      broadcast_append_to user, target: "sessions-tbody", html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
    else
      # If in progress, update the in-progress section
      broadcast_replace_to user, target: "in-progress-drive", html: ApplicationController.render(partial: "drive_sessions/in_progress_drive", locals: { in_progress: self })
    end
    broadcast_progress_summary
  end

  def broadcast_update
    if completed?
      # Check if this was just completed (transitioned from in-progress)
      was_in_progress = saved_change_to_ended_at? && ended_at.present? && ended_at_before_last_save.nil?

      if was_in_progress
        # Drive was just completed - remove from in-progress and add to all drives
        broadcast_remove_to user, target: "in-progress-drive"
        broadcast_append_to user, target: "sessions-tbody", html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
      else
        # Drive was already completed - just update the row
        broadcast_replace_to user, target: ActionView::RecordIdentifier.dom_id(self), html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
      end

      broadcast_recent_drives_table
    else
      # Update in-progress section
      broadcast_replace_to user, target: "in-progress-drive", html: ApplicationController.render(partial: "drive_sessions/in_progress_drive", locals: { in_progress: self })
    end
    broadcast_progress_summary
  end

  def broadcast_destroy
    # Remove from both tables
    broadcast_remove_to user, target: ActionView::RecordIdentifier.dom_id(self)
    broadcast_recent_drives_table
    broadcast_progress_summary
  end

  def broadcast_recent_drives_table
    recent_sessions = user.drive_sessions.completed.ordered.limit(3)
    broadcast_replace_to user, target: "recent-drives-table", html: ApplicationController.render(partial: "drive_sessions/recent_drives_table", locals: { recent_sessions: recent_sessions })
  end

  def broadcast_progress_summary
    # Reset association cache so we always see the latest drives across requests/devices
    user.association(:drive_sessions).reset
    relation = user.drive_sessions

    statistics = DriveSession.statistics_for(relation)
    in_progress = statistics[:in_progress]

    # Get activity data for calendar with user's timezone
    activity_data = relation.activity_by_date(days: ACTIVITY_CALENDAR_DAYS, timezone: user.timezone || "UTC")

    broadcast_replace_to user,
                         target: "progress-summary",
                         html: ApplicationController.render(
                           partial: "drive_sessions/progress_summary",
                           locals: {
                             in_progress: in_progress,
                             total_hours: statistics[:total_hours],
                             night_hours: statistics[:night_hours],
                             activity_calendar: ApplicationController.helpers.activity_calendar_data(activity_data)
                           }
                         )

    # Update mobile in-progress banner on all pages
    broadcast_update_to user,
                        target: "in-progress-banner-container",
                        html: ApplicationController.render(
                          partial: "shared/in_progress_banner",
                          locals: { in_progress: in_progress }
                        )

    # Update floating FAB button (Start vs Complete) on mobile
    broadcast_update_to user,
                        target: "fab-new-drive-wrapper",
                        html: ApplicationController.render(
                          partial: "shared/fab_new_drive",
                          locals: { in_progress: in_progress }
                        )
  end
end
