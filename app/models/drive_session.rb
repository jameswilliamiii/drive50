require "solareventcalculator"

class DriveSession < ApplicationRecord
  include DriveSessionStatistics

  HOURS_NEEDED = 50
  NIGHT_HOURS_NEEDED = 10
  REMINDER_DELAY = 45.minutes
  MAX_DRIVE_DURATION = 7.days

  belongs_to :user

  # Validations
  validates :started_at, presence: true
  validate :ended_at_after_started_at, if: -> { started_at.present? && ended_at.present? }
  # Only when the span itself is being set, so a pre-existing over-long row stays
  # editable (its notes can still be corrected).
  validate :duration_within_maximum, if: -> { ended_at.present? && (started_at_changed? || ended_at_changed?) }

  # Scopes
  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }
  scope :ordered, -> { order(started_at: :desc) }
  # Preload the owning user so views/CSV can render user.full_name without an
  # N+1. Use on any collection whose rows read through the user association.
  scope :with_user, -> { includes(:user) }

  # Callbacks
  # Both derived columns must come from the same start/end pair. Guarding duration
  # on ended_at alone let an edit to just the start time recompute night_minutes
  # against a stale duration, which made day_hours negative.
  before_save :calculate_duration, if: -> { ended_at.present? && (started_at_changed? || ended_at_changed?) }
  before_save :calculate_night_minutes, if: -> { started_at_changed? || ended_at_changed? }
  after_create_commit :broadcast_create
  after_create_commit :schedule_reminder, if: :in_progress?
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_destroy

  # Class methods
  # Groups completed drives by their local date, across exactly the 21 cells the
  # grid renders (3 Sunday-aligned weeks ending with the current week). Days with
  # no drives are simply absent. The grid colours each cell from this and the
  # day-summary modal lists it, so both read one query rather than each computing
  # the same window. Bounded at both ends: an unbounded upper edge loaded rows the
  # grid then silently discarded.
  def self.activity_days(timezone: "UTC")
    tz = resolved_zone(timezone)
    today = Time.current.in_time_zone(tz).to_date
    range_start = today - today.wday - 14
    range_end = range_start + 21 # exclusive: midnight after the last cell

    from = tz.local(range_start.year, range_start.month, range_start.day)
    to = tz.local(range_end.year, range_end.month, range_end.day)

    completed.where(started_at: from...to)
             .order(:started_at)
             .group_by { |session| session.started_at.in_time_zone(tz).to_date }
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

  def night_hours
    (night_minutes / 60.0).round(2)
  end

  # Derived from the already-rounded pair so the three columns in the CSV always
  # reconcile; rounding each independently left ~22% of them off by 0.01.
  def day_hours
    (duration_hours - night_hours).round(2)
  end

  def any_night?
    night_minutes.positive?
  end

  def any_day?
    night_minutes < duration_minutes.to_i
  end

  # A drive that crossed sunset or sunrise, so it earns both day and night credit.
  def day_and_night?
    any_night? && any_day?
  end

  # The three-way classification, as the day summary reports it. The drive row and
  # the detail modal still derive their own from day_and_night? and the night flag;
  # routing those through here too would be the obvious next consolidation.
  def kind
    return :mixed if day_and_night?

    any_night? ? :night : :day
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

  # night_seconds walks one date per calendar day spanned, so an unbounded span is
  # unbounded CPU on a save (a 10-year span measured 1.3s).
  def duration_within_maximum
    if ended_at - started_at > MAX_DRIVE_DURATION
      errors.add(:ended_at, "must be within #{MAX_DRIVE_DURATION.inspect} of the start time")
    end
  end

  def calculate_duration
    return unless started_at && ended_at
    self.duration_minutes = ((ended_at - started_at) / 60).to_i
  end

  # Night is the span between sunset and sunrise, and a drive is credited minute by
  # minute rather than as a whole: crossing sunset splits the drive instead of
  # tipping all of it into the night column.
  def calculate_night_minutes
    return unless started_at

    if ended_at.present?
      # Truncate the same way duration_minutes does — rounding here while duration
      # floors put night one minute over on any drive with a seconds remainder.
      # On the save path calculate_duration has just run on the same span, so the
      # cap is redundant there; it exists for callers that invoke this method
      # directly (the backfill task) against a duration they did not recompute.
      self.night_minutes = [ (night_seconds(started_at, ended_at) / 60).to_i, duration_minutes.to_i ].min
    else
      # An in-progress drive has no span to split yet; statistics only count
      # completed ones.
      self.night_minutes = 0
    end
  end

  # Seconds of [start_at, finish_at] that fall after sunset or before sunrise.
  # Cutting the drive at every solar event it spans (and classifying each piece by
  # its midpoint) keeps overnight and multi-day drives correct for free.
  def night_seconds(start_at, finish_at)
    from = start_at.in_time_zone(user_timezone)
    to = finish_at.in_time_zone(user_timezone)

    # Local midnight has to be a cut point alongside the solar events: night_time?
    # resolves its reference date from the instant it is handed, so a segment that
    # straddles midnight would be classified by a midpoint belonging to only one of
    # the two dates. That goes wrong where an inverted day meets a normal one.
    zone = ActiveSupport::TimeZone[user_timezone]
    crossings = ((from.to_date - 1)..(to.to_date + 1)).flat_map do |date|
      solar_events(date) << zone.local(date.year, date.month, date.day)
    end
    cuts = ([ from, to ] + crossings.compact.select { |event| event > from && event < to }).sort

    cuts.each_cons(2).sum { |a, b| night_time?(a + (b - a) / 2) ? b - a : 0 }
  end

  def night_time?(time)
    local = time.in_time_zone(user_timezone)
    sunrise, sunset = solar_events(local.to_date)

    # nil for both means the sun neither rose nor set, and the gem gives us no way
    # to tell midnight sun from polar night — so we assume daylight. Known gap, and
    # not a theoretical one: at Utqiagvik AK that silently zeroes night credit for
    # ~63 days of continuous darkness a year (145 nil days in 2026, 63 in Nov-Feb).
    return false if sunrise.nil? || sunset.nil?

    # Near the Arctic Circle the window wraps: in early summer the sun sets just
    # after local midnight and rises a few hours later, putting sunset *before*
    # sunrise on the same date. Night is then the interval between the two rather
    # than the two ends of the day. Fairbanks inverts on 46 days a year.
    return local > sunset && local < sunrise if sunrise >= sunset

    local < sunrise || local > sunset
  end

  # Sunrise and sunset for a local calendar date, as instants in the user's zone.
  def solar_events(date)
    calculator = SolarEventCalculator.new(date, coordinates[:lat], coordinates[:lon])

    [ calculator.compute_utc_official_sunrise, calculator.compute_utc_official_sunset ].map do |event|
      local_instant(date, event)
    end
  end

  # RubySunrise returns the correct UTC clock time for each event but stamps it onto
  # the date we passed in, so its raw instant can land on the wrong UTC day (in the
  # Americas sunset is after 00:00 UTC). Rebuild the instant from the event's UTC
  # time-of-day shifted into local time, which never depends on which calendar date
  # the gem chose. The offset is read at local noon so it is the one in effect after
  # any DST change that day, which is when sunrise and sunset both fall.
  def local_instant(date, event)
    return nil if event.nil?

    zone = ActiveSupport::TimeZone[user_timezone]
    offset = zone.local(date.year, date.month, date.day, 12).utc_offset
    seconds = (event.hour * 3600 + event.min * 60 + event.sec + offset) % 86_400

    zone.local(date.year, date.month, date.day, seconds / 3600, (seconds % 3600) / 60, seconds % 60)
  end

  # The name rather than the zone object, because TimezoneCoordinates keys its
  # lookup table on the IANA identifier.
  def user_timezone
    self.class.resolved_zone(user.timezone).name
  end

  def coordinates
    if user.latitude.present? && user.longitude.present?
      { lat: user.latitude.to_f, lon: user.longitude.to_f }
    else
      TimezoneCoordinates.coordinates_for_timezone(user_timezone)
    end
  end

  def broadcast_create
    if completed?
      broadcast_recent_drives_table
      broadcast_append_to user, target: "sessions-list", html: ApplicationController.render(partial: "drive_sessions/drive_row", locals: { session: self })
    end
    broadcast_progress_summary
  end

  def broadcast_update
    if completed?
      was_in_progress = saved_change_to_ended_at? && ended_at.present? && ended_at_before_last_save.nil?

      if was_in_progress
        broadcast_append_to user, target: "sessions-list", html: ApplicationController.render(partial: "drive_sessions/drive_row", locals: { session: self })
      else
        broadcast_replace_to user, target: ActionView::RecordIdentifier.dom_id(self), html: ApplicationController.render(partial: "drive_sessions/drive_row", locals: { session: self })
      end

      broadcast_recent_drives_table
    end
    broadcast_progress_summary
  end

  def broadcast_destroy
    broadcast_remove_to user, target: ActionView::RecordIdentifier.dom_id(self)
    broadcast_recent_drives_table
    broadcast_progress_summary
  end

  def broadcast_recent_drives_table
    recent_sessions = user.drive_sessions.completed.ordered.with_user.limit(3)
    broadcast_replace_to user, target: "recent-drives-table", html: ApplicationController.render(partial: "drive_sessions/recent_drives_table", locals: { recent_sessions: recent_sessions })
  end

  def broadcast_progress_summary
    user.association(:drive_sessions).reset
    relation = user.drive_sessions
    tz = user.timezone || "UTC"

    statistics = DriveSession.statistics_for(relation, timezone: tz)
    activity_cells = ActivityDay.grid_for(relation.activity_days(timezone: tz), timezone: tz)

    broadcast_replace_to user,
                         target: "progress-summary",
                         html: ApplicationController.render(
                           partial: "drive_sessions/progress_summary",
                           locals: { stats: statistics, activity_cells: activity_cells }
                         )

    broadcast_update_to user,
                        target: "in-progress-banner-container",
                        html: ApplicationController.render(
                          partial: "shared/in_progress_banner",
                          locals: { in_progress: statistics[:in_progress] }
                        )

    broadcast_update_to user,
                        target: "fab-new-drive-wrapper",
                        html: ApplicationController.render(
                          partial: "shared/fab_new_drive",
                          locals: { in_progress: statistics[:in_progress] }
                        )
  end

  def schedule_reminder
    # Only schedule if user has push subscriptions
    return unless user.push_subscriptions.exists?

    DriveSessionReminderJob.set(wait: REMINDER_DELAY).perform_later(id)
  end
end
