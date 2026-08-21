# Duration strings, split out of DriveSessionHelper because ActivityDay builds the
# same strings for the day-summary payload and a view helper is not reachable from
# a plain object. Templates still get both methods because DriveSessionHelper
# includes this and *that* helper is auto-mixed into views — Rails only auto-mixes
# files named *_helper.rb, so the include below is load-bearing, not redundant.
module DurationFormatting
  def format_duration(hours_decimal)
    spelled(hours_decimal, hour: "hr", minute: "min")
  end

  # Compact "4h 55m": what the app shows wherever a duration is read as a value.
  # The long form is for prose.
  def format_duration_short(hours_decimal, style_units: false)
    hours, minutes = split_duration(hours_decimal)

    parts = []
    parts << unit_pair(hours, "h", style_units) if hours.positive? || minutes.zero?
    parts << unit_pair(minutes, "m", style_units) if minutes.positive?
    joined = parts.join(" ")
    style_units ? joined.html_safe : joined
  end

  # For text that exists only to be announced, never shown — an aria label can
  # spell the units out at no cost to the layout. Visible durations are announced
  # as written, abbreviations and all; that is the trade the compact form makes.
  def format_duration_spoken(hours_decimal)
    spelled(hours_decimal, hour: "hour", minute: "minute")
  end

  private

  def spelled(hours_decimal, hour:, minute:)
    hours, minutes = split_duration(hours_decimal)
    return "0 #{hour.pluralize(0)}" if hours.zero? && minutes.zero?

    parts = []
    parts << "#{hours} #{hour.pluralize(hours)}" if hours.positive?
    parts << "#{minutes} #{minute.pluralize(minutes)}" if minutes.positive?
    parts.join(" ")
  end

  # Clamped, so every caller gets a duration back: divmod on a negative splits into
  # a negative hour and a *positive* minute, and -0.5 would render "30m". This is
  # the backstop, not the check — night_minutes <= duration_minutes is what keeps
  # day_hours non-negative in the first place.
  def split_duration(hours_decimal)
    [ (hours_decimal.to_f * 60).round, 0 ].max.divmod(60)
  end

  def unit_pair(value, unit, style_units)
    style_units ? "#{value}<span class='unit'>#{unit}</span>" : "#{value}#{unit}"
  end
end
