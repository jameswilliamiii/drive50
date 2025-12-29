module DriveSessionHelper
  def format_duration(hours_decimal, style_units: false)
    return style_units ? "0 <span class='unit'>hrs</span>".html_safe : "0 hrs" if hours_decimal.nil? || hours_decimal.zero?

    total_minutes = (hours_decimal * 60).round
    hours = total_minutes / 60
    minutes = total_minutes % 60

    if style_units
      if hours > 0 && minutes > 0
        "#{hours} <span class='unit'>hrs</span> #{minutes} <span class='unit'>mins</span>".html_safe
      elsif hours > 0
        "#{hours} <span class='unit'>#{'hr'.pluralize(hours)}</span>".html_safe
      else
        "#{minutes} <span class='unit'>mins</span>".html_safe
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

  def circular_progress(current:, total:, size: 120, stroke_width: 8)
    percentage = (current.to_f / total * 100).clamp(0, 100)
    radius = (size - stroke_width) / 2
    circumference = 2 * Math::PI * radius
    stroke_offset = circumference - (percentage / 100 * circumference)

    raw(<<~SVG.squish)
      <svg class="circular-progress" width="#{size}" height="#{size}" viewBox="0 0 #{size} #{size}">
        <defs>
          <linearGradient id="progress-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#1d4ed8;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#2563eb;stop-opacity:1" />
          </linearGradient>
        </defs>
        <circle class="progress-bg" cx="#{size / 2}" cy="#{size / 2}" r="#{radius}" fill="none" stroke-width="#{stroke_width}"/>
        <circle class="progress-bar" cx="#{size / 2}" cy="#{size / 2}" r="#{radius}" fill="none" stroke-width="#{stroke_width}"
                stroke-dasharray="#{circumference}" stroke-dashoffset="#{stroke_offset}"
                transform="rotate(-90 #{size / 2} #{size / 2})"/>
      </svg>
    SVG
  end

  def activity_calendar_data(activity_data, days: 28)
    end_date = Date.today
    start_date = end_date - (days - 1).days

    # Generate all dates in range
    calendar_days = (start_date..end_date).map do |date|
      count = activity_data[date] || 0
      level = case count
      when 0 then 0
      when 1 then 1
      when 2 then 2
      when 3 then 3
      else 4
      end

      {
        date: date,
        count: count,
        level: level
      }
    end

    # Calculate weeks for label
    weeks = (days / 7.0).round

    {
      days: calendar_days,
      label: weeks == 1 ? "Last week" : "Last #{weeks} weeks",
      total_days: days
    }
  end
end
