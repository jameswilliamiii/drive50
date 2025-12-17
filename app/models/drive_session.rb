class DriveSession < ApplicationRecord
  HOURS_NEEDED = 50
  NIGHT_HOURS_NEEDED = 10

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

    # Simple heuristic: 8pm - 6am is night
    # For production, could use sunrise/sunset API
    hour = started_at.hour
    self.is_night_drive = hour >= 20 || hour < 6
  end

  def broadcast_create
    if completed?
      # If completed, add to recent drives (if in top 3) and all drives
      recent_sessions = user.drive_sessions.completed.ordered.limit(3)
      broadcast_replace_to user, target: "recent-drives-table", html: ApplicationController.render(partial: "drive_sessions/recent_drives_table", locals: { recent_sessions: recent_sessions })
      broadcast_append_to user, target: "sessions-tbody", html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
    else
      # If in progress, update the in-progress section
      broadcast_replace_to user, target: "in-progress-drive", html: ApplicationController.render(partial: "drive_sessions/in_progress_drive", locals: { in_progress: self })
    end
    # Update stats
    in_progress = user.drive_sessions.in_progress.first
    total_hours = user.drive_sessions.completed.sum(:duration_minutes) / 60.0
    night_hours = user.drive_sessions.night_drives.completed.sum(:duration_minutes) / 60.0
    broadcast_replace_to user, target: "progress-summary", html: ApplicationController.render(partial: "drive_sessions/progress_summary", locals: {
      in_progress: in_progress,
      total_hours: total_hours,
      night_hours: night_hours
    })
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

      # Update recent drives table
      recent_sessions = user.drive_sessions.completed.ordered.limit(3)
      broadcast_replace_to user, target: "recent-drives-table", html: ApplicationController.render(partial: "drive_sessions/recent_drives_table", locals: { recent_sessions: recent_sessions })
    else
      # Update in-progress section
      broadcast_replace_to user, target: "in-progress-drive", html: ApplicationController.render(partial: "drive_sessions/in_progress_drive", locals: { in_progress: self })
    end
    # Update stats
    in_progress = user.drive_sessions.in_progress.first
    total_hours = user.drive_sessions.completed.sum(:duration_minutes) / 60.0
    night_hours = user.drive_sessions.night_drives.completed.sum(:duration_minutes) / 60.0
    broadcast_replace_to user, target: "progress-summary", html: ApplicationController.render(partial: "drive_sessions/progress_summary", locals: {
      in_progress: in_progress,
      total_hours: total_hours,
      night_hours: night_hours
    })
  end

  def broadcast_destroy
    # Remove from both tables
    broadcast_remove_to user, target: ActionView::RecordIdentifier.dom_id(self)
    # Update recent drives table (load next oldest if needed)
    recent_sessions = user.drive_sessions.completed.ordered.limit(3)
    broadcast_replace_to user, target: "recent-drives-table", html: ApplicationController.render(partial: "drive_sessions/recent_drives_table", locals: { recent_sessions: recent_sessions })
    # Update stats
    in_progress = user.drive_sessions.in_progress.first
    total_hours = user.drive_sessions.completed.sum(:duration_minutes) / 60.0
    night_hours = user.drive_sessions.night_drives.completed.sum(:duration_minutes) / 60.0
    broadcast_replace_to user, target: "progress-summary", html: ApplicationController.render(partial: "drive_sessions/progress_summary", locals: {
      in_progress: in_progress,
      total_hours: total_hours,
      night_hours: night_hours
    })
  end
end
