class WeeklyMotivationNotifier
  INACTIVE_AFTER = 5.weeks
  ALMOST_DONE_HOURS = 5
  TIMEZONE = User::DEFAULT_TIMEZONE

  class << self
    include DurationFormatting

    def candidates
      User
        .where(weekly_motivation_enabled: true)
        .where("weekly_motivation_sent_on IS NULL OR weekly_motivation_sent_on != ?", today)
        .joins(:push_subscriptions, :drive_sessions)
        .merge(DriveSession.completed.where(ended_at: inactive_cutoff..))
        .distinct
    end

    def message_for(user)
      return unless eligible_basics?(user)

      stats = DriveSession.statistics_for(user, timezone: TIMEZONE)
      total_remaining = stats[:hours_needed]
      night_remaining = stats[:night_hours_needed]

      return if total_remaining <= 0 && night_remaining <= 0

      if total_remaining.positive?
        total_message(total_remaining, stats[:last_week_hours])
      else
        night_message(night_remaining)
      end
    end

    private

    # Guards for callers that skip `.candidates` (tests, console). The job path
    # already SQL-filters preference, sent-on, subscriptions, and recent drives.
    def eligible_basics?(user)
      user.weekly_motivation_enabled? &&
        user.push_subscriptions.exists? &&
        user.drive_sessions.completed.where(ended_at: inactive_cutoff..).exists? &&
        user.weekly_motivation_sent_on != today
    end

    def total_message(remaining, last_week)
      if remaining <= ALMOST_DONE_HOURS
        {
          title: "Almost there",
          body: "Only #{format_duration_spoken(remaining)} left. You're so close — log a drive this week."
        }
      elsif last_week.positive?
        {
          title: "Keep it up",
          body: "You drove #{format_duration_spoken(last_week)} last week. #{format_duration_spoken(remaining)} to go — a little this week keeps you on track."
        }
      else
        {
          title: "Ready for a drive?",
          body: "#{format_duration_spoken(remaining)} left toward your goal. Even a short session this week helps."
        }
      end
    end

    def night_message(remaining)
      if remaining <= ALMOST_DONE_HOURS
        {
          title: "Finish strong",
          body: "Just #{format_duration_spoken(remaining)} of night driving left. You're nearly done."
        }
      else
        {
          title: "Night hours needed",
          body: "You've hit your total hours — #{format_duration_spoken(remaining)} of night driving left."
        }
      end
    end

    def today
      Time.current.in_time_zone(TIMEZONE).to_date
    end

    def inactive_cutoff
      Time.current.in_time_zone(TIMEZONE) - INACTIVE_AFTER
    end
  end
end
