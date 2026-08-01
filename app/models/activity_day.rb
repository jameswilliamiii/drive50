# One cell of the Momentum grid: a local date, the completed drives that fall on
# it, and the derived values the grid markup and the day-summary modal both read.
#
# Exists so the day's numbers are computed once per cell — the aria label and the
# JSON payload were each summing the same drives — and so the shape passed through
# the controller, the view and the Turbo broadcast has a name.
class ActivityDay
  include ActionView::Helpers::TextHelper
  include DurationFormatting

  CELLS = 21 # 3 Sunday-aligned weeks, ending with the current week

  attr_reader :date, :drives

  # The grid, oldest cell first. Days with no drives get an empty one rather than
  # being absent, because every cell is rendered either way.
  def self.grid_for(drives_by_date, timezone: "UTC")
    zone = DriveSession.resolved_zone(timezone)
    today = Time.current.in_time_zone(zone).to_date
    first = today - today.wday - (CELLS - 7)

    (first...(first + CELLS)).map do |date|
      new(date: date, drives: drives_by_date[date] || [], today: today, zone: zone)
    end
  end

  def initialize(date:, drives:, today:, zone:)
    @date = date
    @drives = drives
    @today = today
    @zone = zone
  end

  def today?
    date == @today
  end

  def future?
    date > @today
  end

  def any_drives?
    drives.any?
  end

  # :both when the day holds any daylight driving and any night driving — which a
  # single drive can do on its own once it crosses sunset.
  def state
    return :none unless any_drives?

    night = drives.any?(&:any_night?)
    day = drives.any?(&:any_day?)

    if day && night then :both
    elsif night then :night
    # A drive whose duration truncates to zero minutes credits neither, but it
    # still happened — leaving it :none painted the cell empty while the same cell
    # announced "1 drive" and opened a summary.
    else :day
    end
  end

  def aria_label
    label = date.strftime("%B %-d")
    return "#{label}, no drives" unless any_drives?

    "#{label}, #{pluralize(drives.size, 'drive')}, #{total}"
  end

  # Everything the day-summary modal renders. Clock times are formatted here, in
  # the same zone the cell was grouped by, so the modal's heading and its rows can
  # never describe different local days — the browser's zone can disagree with the
  # stored one until the next timezone sync.
  def as_json(*)
    {
      label: date.strftime("%A, %B %-d, %Y"),
      count: drives.size,
      total: total,
      day: duration_or_nil(total_minutes - night_minutes),
      night: duration_or_nil(night_minutes),
      drives: drives.map { |drive| drive_json(drive) }
    }.compact
  end

  private

  def total
    format_duration(total_minutes / 60.0)
  end

  def total_minutes
    drives.sum { |drive| drive.duration_minutes.to_i }
  end

  def night_minutes
    drives.sum(&:night_minutes)
  end

  def duration_or_nil(minutes)
    format_duration(minutes / 60.0) if minutes.positive?
  end

  def drive_json(drive)
    {
      time: "#{clock(drive.started_at)} – #{clock(drive.ended_at)}",
      duration: format_duration(drive.duration_hours),
      kind: drive.kind
    }
  end

  def clock(time)
    time.in_time_zone(@zone).strftime("%-l:%M %p")
  end
end
