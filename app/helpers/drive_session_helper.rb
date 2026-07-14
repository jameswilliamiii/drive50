module DriveSessionHelper
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
        "#{hours} hrs #{minutes} mins"
      elsif hours > 0
        "#{hours} #{'hr'.pluralize(hours)}"
      else
        "#{minutes} mins"
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

  # Time-of-day greeting in the user's own timezone, personalized when we know
  # their name.
  def dashboard_greeting(user)
    tz = ActiveSupport::TimeZone[user.timezone.presence || "UTC"]
    part = case Time.current.in_time_zone(tz).hour
    when 5..11 then "Good morning"
    when 12..16 then "Good afternoon"
    else "Good evening"
    end
    user.name.present? ? "#{part}, #{user.name.split.first}" : part
  end

  # Expands a { Date => state } hash into 21 Sunday-aligned cells (3 weeks).
  def dashboard_activity_days(states, timezone: "UTC")
    tz = ActiveSupport::TimeZone[timezone || "UTC"]
    today = Time.current.in_time_zone(tz).to_date
    start_of_week = today - today.wday
    range_start = start_of_week - 14

    (range_start..(start_of_week + 6)).map do |date|
      {
        date: date,
        state: states[date] || :none,
        today: date == today,
        future: date > today
      }
    end
  end
end
