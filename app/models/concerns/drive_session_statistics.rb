module DriveSessionStatistics
  extend ActiveSupport::Concern

  included do
    # Make these methods available on the DriveSession class
  end

  class_methods do
    # Calculate all statistics for a user's drive sessions
    def statistics_for(user_or_relation, timezone: "UTC")
      relation = user_or_relation.is_a?(ActiveRecord::Relation) ? user_or_relation : user_or_relation.drive_sessions
      completed = relation.completed

      total_minutes = completed.sum(:duration_minutes)
      night_minutes = completed.where(is_night_drive: true).sum(:duration_minutes)
      total_hours = total_minutes / 60.0
      night_hours = night_minutes / 60.0

      dates = relation.active_dates(timezone: timezone)
      pace = relation.weekly_pace(timezone: timezone)

      {
        total_hours: total_hours,
        night_hours: night_hours,
        day_hours: (total_minutes - night_minutes) / 60.0,
        hours_needed: [ DriveSession::HOURS_NEEDED - total_hours, 0 ].max,
        night_hours_needed: [ DriveSession::NIGHT_HOURS_NEEDED - night_hours, 0 ].max,
        drives_count: completed.count,
        in_progress: relation.in_progress.first,
        this_week_hours: relation.hours_in_week(0, timezone: timezone),
        last_week_hours: relation.hours_in_week(1, timezone: timezone),
        active_days: relation.active_day_count(days: 21, timezone: timezone, dates: dates),
        current_streak: relation.current_streak(timezone: timezone, dates: dates),
        best_streak: relation.best_streak(timezone: timezone, dates: dates),
        weekly_pace: pace,
        projected_finish: relation.projected_finish(timezone: timezone, pace: pace)
      }
    end

    def day_hours
      completed.where(is_night_drive: false).sum(:duration_minutes) / 60.0
    end

    def drives_count
      completed.count
    end

    # weeks_ago: 0 = current calendar week, 1 = previous, etc. Sunday-start, in the given tz.
    def hours_in_week(weeks_ago, timezone: "UTC")
      tz = ActiveSupport::TimeZone[timezone || "UTC"]
      today = Time.current.in_time_zone(tz).to_date
      start_date = today - today.wday - (weeks_ago * 7)
      start_dt = tz.local(start_date.year, start_date.month, start_date.day)
      end_dt = start_dt + 7.days
      completed.where(started_at: start_dt...end_dt).sum(:duration_minutes) / 60.0
    end

    # Distinct local dates (user tz) that have at least one completed drive, ascending.
    def active_dates(timezone: "UTC")
      tz = ActiveSupport::TimeZone[timezone || "UTC"]
      completed.pluck(:started_at).map { |t| t.in_time_zone(tz).to_date }.uniq.sort
    end

    def active_day_count(days: 21, timezone: "UTC", dates: nil)
      dates ||= active_dates(timezone: timezone)
      tz = ActiveSupport::TimeZone[timezone || "UTC"]
      today = Time.current.in_time_zone(tz).to_date
      cutoff = today - (days - 1)
      dates.count { |d| d >= cutoff && d <= today }
    end

    def current_streak(timezone: "UTC", dates: nil)
      tz = ActiveSupport::TimeZone[timezone || "UTC"]
      today = Time.current.in_time_zone(tz).to_date
      set = (dates || active_dates(timezone: timezone)).to_set
      return 0 if set.empty?

      cursor = set.include?(today) ? today : today - 1
      return 0 unless set.include?(cursor)

      streak = 0
      while set.include?(cursor)
        streak += 1
        cursor -= 1
      end
      streak
    end

    def best_streak(timezone: "UTC", dates: nil)
      best = 0
      run = 0
      prev = nil
      (dates || active_dates(timezone: timezone)).each do |date|
        run = (prev && date == prev + 1) ? run + 1 : 1
        best = run if run > best
        prev = date
      end
      best
    end

    def weekly_pace(timezone: "UTC")
      tz = ActiveSupport::TimeZone[timezone || "UTC"]
      first = completed.minimum(:started_at)
      return 0.0 if first.nil?

      recent_hours = completed.where("started_at >= ?", 28.days.ago).sum(:duration_minutes) / 60.0
      today = Time.current.in_time_zone(tz).to_date
      days_of_history = (today - first.in_time_zone(tz).to_date).to_i + 1
      weeks = [ [ (days_of_history / 7.0).round, 4 ].min, 1 ].max
      (recent_hours / weeks).round(1)
    end

    # Human-readable label so the view stays dumb: "Early October", "Keep driving", or "Complete".
    def projected_finish(timezone: "UTC", pace: nil)
      remaining = [ DriveSession::HOURS_NEEDED - (completed.sum(:duration_minutes) / 60.0), 0 ].max
      return "Complete" if remaining <= 0

      pace ||= weekly_pace(timezone: timezone)
      return "Keep driving" if pace <= 0

      weeks_left = remaining / pace
      date = Date.current + (weeks_left * 7).ceil
      part = date.day <= 10 ? "Early" : (date.day <= 20 ? "Mid" : "Late")
      "#{part} #{date.strftime('%B')}"
    end
  end
end
