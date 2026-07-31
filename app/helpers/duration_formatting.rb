# Duration strings, split out of DriveSessionHelper because ActivityDay builds the
# same strings for the day-summary payload and a view helper is not reachable from
# a plain object. Templates still get both methods because DriveSessionHelper
# includes this and *that* helper is auto-mixed into views — Rails only auto-mixes
# files named *_helper.rb, so the include below is load-bearing, not redundant.
module DurationFormatting
  def format_duration(hours_decimal, style_units: false)
    return style_units ? "0 <span class='unit'>hrs</span>".html_safe : "0 hrs" if hours_decimal.nil? || hours_decimal.zero?

    total_minutes = (hours_decimal * 60).round
    hours = total_minutes / 60
    minutes = total_minutes % 60

    if style_units
      if hours > 0 && minutes > 0
        "#{hours} <span class='unit'>#{'hr'.pluralize(hours)}</span> #{minutes} <span class='unit'>#{'min'.pluralize(minutes)}</span>".html_safe
      elsif hours > 0
        "#{hours} <span class='unit'>#{'hr'.pluralize(hours)}</span>".html_safe
      else
        "#{minutes} <span class='unit'>#{'min'.pluralize(minutes)}</span>".html_safe
      end
    else
      if hours > 0 && minutes > 0
        "#{hours} #{'hr'.pluralize(hours)} #{minutes} #{'min'.pluralize(minutes)}"
      elsif hours > 0
        "#{hours} #{'hr'.pluralize(hours)}"
      else
        "#{minutes} #{'min'.pluralize(minutes)}"
      end
    end
  end

  # Compact "4h 55m" duration for tight stat chips, mirroring the hero's terse
  # chip values.
  def format_duration_short(hours_decimal)
    return "0h" if hours_decimal.nil? || hours_decimal.zero?

    hours, minutes = (hours_decimal * 60).round.divmod(60)
    if hours.positive? && minutes.positive?
      "#{hours}h #{minutes}m"
    elsif hours.positive?
      "#{hours}h"
    else
      "#{minutes}m"
    end
  end
end
