require "test_helper"

class DriveSessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
  end

  test "creating and completing a drive broadcasts without error" do
    @user.update!(timezone: "America/Chicago")
    assert_nothing_raised do
      d = @user.drive_sessions.create!(started_at: 2.hours.ago)
      d.update!(ended_at: Time.current)
      d.destroy!
    end
  end

  # Validations
  test "requires started_at" do
    session = @user.drive_sessions.new
    assert_not session.valid?
    assert_includes session.errors[:started_at], "can't be blank"
  end

  test "requires ended_at to be after started_at" do
    session = @user.drive_sessions.new(
      started_at: Time.current,
      ended_at: 1.hour.ago
    )
    assert_not session.valid?
    assert_includes session.errors[:ended_at], "must be after start time"
  end

  # Calculations
  test "calculates duration on save" do
    session = @user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )

    assert_equal 60, session.duration_minutes
  end

  test "determines night drive based on sunset/sunrise times in winter" do
    # Set user timezone and location (Chicago)
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    # Winter: sunset around 4:50pm
    winter_date = Date.new(2024, 12, 15)
    tz = ActiveSupport::TimeZone.new("America/Chicago")

    # 5pm drive in winter should be night (after sunset)
    night_session = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 17, 0, 0),
      ended_at: tz.local(2024, 12, 15, 18, 0, 0)
    )
    assert night_session.is_night_drive, "5pm in winter should be night drive"

    # 2pm drive in winter should be day (before sunset)
    day_session = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 14, 0, 0),
      ended_at: tz.local(2024, 12, 15, 15, 0, 0)
    )
    assert_not day_session.is_night_drive, "2pm in winter should be day drive"
  end

  test "midday summer drives are day, not night, across timezones" do
    # Regression: the sunrise/sunset gem stamps the event's UTC time onto the local
    # date without letting it roll to the next UTC day. In summer, sunset falls after
    # 00:00 UTC, so it landed a day early and every daytime drive was flagged night.
    [
      [ "America/Chicago", 41.8781, -87.6298 ],
      [ "America/Los_Angeles", 34.0522, -118.2437 ],
      [ "America/New_York", 40.7128, -74.0060 ],
      [ "Pacific/Honolulu", 21.3099, -157.8581 ]
    ].each do |zone, lat, lon|
      @user.update!(timezone: zone, latitude: lat, longitude: lon)
      tz = ActiveSupport::TimeZone.new(zone)

      noon = @user.drive_sessions.create!(
        started_at: tz.local(2026, 7, 8, 12, 0, 0),
        ended_at: tz.local(2026, 7, 8, 13, 0, 0)
      )
      assert_not noon.is_night_drive, "noon in #{zone} (summer) should be a day drive"
    end
  end

  test "determines night drive for early morning" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    night_session = @user.drive_sessions.create!(
      started_at: Time.current.change(hour: 2),
      ended_at: Time.current.change(hour: 3)
    )
    assert night_session.is_night_drive, "Early morning should be night drive"
  end

  test "uses timezone fallback when user has no coordinates" do
    # User has timezone but no lat/long
    @user.update!(timezone: "America/Chicago", latitude: nil, longitude: nil)

    tz = ActiveSupport::TimeZone.new("America/Chicago")

    # Should still work using timezone-based coordinates
    night_session = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 21, 0, 0),
      ended_at: tz.local(2024, 12, 15, 22, 0, 0)
    )
    assert night_session.is_night_drive, "Should use timezone fallback coordinates"
  end

  test "night_time? handles polar regions with no sunset" do
    @user.update!(timezone: "UTC", latitude: 89.0, longitude: 0.0) # Near North Pole

    # During polar summer, there may be no sunset
    # Should return false (not night) when sunrise/sunset are nil
    time = Time.zone.parse("2024-06-15 12:00:00")
    session = @user.drive_sessions.new()

    # This should not raise an error
    assert_nothing_raised do
      result = session.send(:night_time?, time, 89.0, 0.0)
      assert_equal false, result
    end
  end

  test "duration_hours returns 0 for nil duration" do
    session = @user.drive_sessions.new(started_at: Time.current)
    assert_equal 0, session.duration_hours
  end

  test "duration_hours converts minutes to hours" do
    session = @user.drive_sessions.create!(
      started_at: 2.hours.ago,
      ended_at: Time.current
    )
    assert_in_delta 2.0, session.duration_hours, 0.1
  end

  # Scopes
  test "completed scope returns only completed sessions" do
    completed = @user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    in_progress = @user.drive_sessions.create!(
      started_at: Time.current
    )

    assert_includes @user.drive_sessions.completed, completed
    assert_not_includes @user.drive_sessions.completed, in_progress
  end

  test "in_progress scope returns only in-progress sessions" do
    completed = @user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    in_progress = @user.drive_sessions.create!(
      started_at: Time.current
    )

    assert_includes @user.drive_sessions.in_progress, in_progress
    assert_not_includes @user.drive_sessions.in_progress, completed
  end

  test "night_drives scope returns only night drives" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    tz = ActiveSupport::TimeZone.new("America/Chicago")

    night = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 21, 0, 0),
      ended_at: tz.local(2024, 12, 15, 22, 0, 0)
    )
    day = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 14, 0, 0),
      ended_at: tz.local(2024, 12, 15, 15, 0, 0)
    )

    assert_includes @user.drive_sessions.night_drives, night
    assert_not_includes @user.drive_sessions.night_drives, day
  end

  test "ordered scope returns sessions in reverse chronological order" do
    @user.drive_sessions.destroy_all
    first = @user.drive_sessions.create!(
      started_at: 3.hours.ago,
      ended_at: 2.hours.ago
    )
    second = @user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )

    ordered = @user.drive_sessions.ordered
    assert_equal second, ordered.first
    assert_equal first, ordered.last
  end

  # Instance methods
  test "completed? returns true when ended_at is present" do
    session = @user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    assert session.completed?
  end

  test "completed? returns false when ended_at is nil" do
    session = @user.drive_sessions.create!(
      started_at: Time.current
    )
    assert_not session.completed?
  end

  test "in_progress? returns true when ended_at is nil" do
    session = @user.drive_sessions.create!(
      started_at: Time.current
    )
    assert session.in_progress?
  end

  test "in_progress? returns false when ended_at is present" do
    session = @user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    assert_not session.in_progress?
  end

  test "elapsed_time returns formatted time for in-progress session" do
    session = @user.drive_sessions.create!(
      started_at: 30.minutes.ago
    )
    assert_match(/\d+m/, session.elapsed_time)
  end

  test "elapsed_time returns nil for completed session" do
    session = @user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    assert_nil session.elapsed_time
  end

  # Class methods
  test "total_hours calculates total completed hours" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )
    @user.drive_sessions.create!(
      started_at: 3.hours.ago,
      ended_at: 2.hours.ago
    )

    assert_in_delta 2.0, @user.drive_sessions.total_hours, 0.1
  end

  test "night_hours calculates total night hours" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    tz = ActiveSupport::TimeZone.new("America/Chicago")
    @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 21, 0, 0),
      ended_at: tz.local(2024, 12, 15, 22, 0, 0)
    )

    assert_in_delta 1.0, @user.drive_sessions.night_hours, 0.1
  end

  test "hours_needed returns remaining hours" do
    # Create sessions totaling 45 hours
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      started_at: 45.hours.ago,
      ended_at: Time.current
    )

    assert_in_delta 5.0, @user.drive_sessions.hours_needed, 0.1
  end

  test "hours_needed returns 0 when requirement is met" do
    # Create sessions totaling more than 50 hours
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      started_at: 51.hours.ago,
      ended_at: Time.current
    )

    assert_equal 0, @user.drive_sessions.hours_needed
  end

  test "night_hours_needed returns remaining night hours" do
    @user.drive_sessions.destroy_all
    # Create a 5-hour night drive (9pm to 2am)
    @user.drive_sessions.create!(
      started_at: Time.current.change(hour: 21),
      ended_at: Time.current.tomorrow.change(hour: 2)
    )

    assert_in_delta 5.0, @user.drive_sessions.night_hours_needed, 0.1
  end

  test "night_hours_needed returns 0 when requirement is met" do
    @user.drive_sessions.destroy_all
    # Create a night drive that's at least 11 hours to meet requirement
    # Started at 9pm yesterday, ended at 8am today (11 hours at night)
    yesterday = 1.day.ago
    @user.drive_sessions.create!(
      started_at: yesterday.change(hour: 21),
      ended_at: yesterday.tomorrow.change(hour: 8)
    )

    assert_equal 0, @user.drive_sessions.night_hours_needed
  end

  # Statistics
  test "statistics_for returns all statistics" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      started_at: 10.hours.ago,
      ended_at: Time.current
    )

    stats = DriveSession.statistics_for(@user)
    assert_equal 10.0, stats[:total_hours]
    assert_equal 40.0, stats[:hours_needed]
    assert_kind_of Hash, stats
    assert stats.key?(:night_hours)
    assert stats.key?(:night_hours_needed)
    assert stats.key?(:in_progress)
  end

  test "statistics_for includes the new dashboard metrics" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    @user.drive_sessions.create!(started_at: 2.hours.ago, ended_at: 1.hour.ago)
    stats = DriveSession.statistics_for(@user, timezone: "America/Chicago")
    [ :day_hours, :drives_count, :this_week_hours, :last_week_hours,
      :active_days, :current_streak, :best_streak, :weekly_pace, :projected_finish ].each do |key|
      assert stats.key?(key), "expected statistics_for to include #{key}"
    end
  end

  # Activity Calendar
  test "ACTIVITY_CALENDAR_DAYS constant is set" do
    assert_equal 28, DriveSession::ACTIVITY_CALENDAR_DAYS
  end

  test "activity_by_date returns hash of dates to counts" do
    travel_to Time.zone.local(2025, 1, 15, 12, 0, 0) do
      @user.drive_sessions.destroy_all

      # Create drives on specific dates in UTC
      3.times do
        @user.drive_sessions.create!(
          started_at: 2.days.ago.beginning_of_day + 10.hours,
          ended_at: 2.days.ago.beginning_of_day + 11.hours
        )
      end

      2.times do
        @user.drive_sessions.create!(
          started_at: 1.day.ago.beginning_of_day + 10.hours,
          ended_at: 1.day.ago.beginning_of_day + 11.hours
        )
      end

      result = @user.drive_sessions.activity_by_date(days: 28, timezone: "UTC")

      assert_equal 3, result[2.days.ago.to_date]
      assert_equal 2, result[1.day.ago.to_date]
      assert_nil result[Date.today]
    end
  end

  test "activity_by_date respects timezone parameter" do
    @user.drive_sessions.destroy_all

    # Create a drive at 11 PM UTC on a specific date
    # In Tokyo (UTC+9), this would be 8 AM the next day
    drive_time = 2.days.ago.beginning_of_day.utc + 23.hours
    @user.drive_sessions.create!(
      started_at: drive_time,
      ended_at: drive_time + 1.hour
    )

    utc_result = @user.drive_sessions.activity_by_date(days: 365, timezone: "UTC")
    tokyo_result = @user.drive_sessions.activity_by_date(days: 365, timezone: "Asia/Tokyo")

    # UTC should count it on the date at 11 PM UTC
    utc_date = drive_time.in_time_zone("UTC").to_date
    # Tokyo should count it on the next day (since 11 PM UTC = 8 AM next day in Tokyo)
    tokyo_date = drive_time.in_time_zone("Asia/Tokyo").to_date

    assert_equal 1, utc_result[utc_date]
    assert_equal 1, tokyo_result[tokyo_date]
  end

  test "activity_by_date only includes completed drives" do
    @user.drive_sessions.destroy_all

    # Use UTC timezone consistently to avoid timezone mismatches
    drive_date = 1.day.ago.utc
    drive_started_at = drive_date
    drive_ended_at = drive_date + 1.hour

    # Completed drive
    @user.drive_sessions.create!(
      started_at: drive_started_at,
      ended_at: drive_ended_at
    )

    # In-progress drive
    @user.drive_sessions.create!(
      started_at: drive_started_at
    )

    result = @user.drive_sessions.activity_by_date(days: 28, timezone: "UTC")
    assert_equal 1, result[drive_started_at.to_date]
  end

  test "activity_by_date filters by date range" do
    @user.drive_sessions.destroy_all

    # Drive within range (10 days ago)
    @user.drive_sessions.create!(
      started_at: 10.days.ago,
      ended_at: 10.days.ago + 1.hour
    )

    # Drive outside range (40 days ago)
    @user.drive_sessions.create!(
      started_at: 40.days.ago,
      ended_at: 40.days.ago + 1.hour
    )

    result = @user.drive_sessions.activity_by_date(days: 28)
    assert_equal 1, result.values.sum
  end

  test "activity_by_date handles nil timezone gracefully" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      started_at: 1.day.ago,
      ended_at: 1.day.ago + 1.hour
    )

    # Should not raise error and should default to Time.zone or UTC
    assert_nothing_raised do
      result = @user.drive_sessions.activity_by_date(days: 28, timezone: nil)
      assert_kind_of Hash, result
      assert_equal 1, result.values.sum
    end
  end

  test "activity_by_date handles empty results" do
    @user.drive_sessions.destroy_all

    result = @user.drive_sessions.activity_by_date(days: 28)
    assert_equal({}, result)
    assert_kind_of Hash, result
  end

  test "activity_by_date groups multiple drives on same date" do
    @user.drive_sessions.destroy_all

    # Create 5 drives on the same date
    date = 5.days.ago.beginning_of_day
    5.times do |i|
      @user.drive_sessions.create!(
        started_at: date + i.hours,
        ended_at: date + i.hours + 30.minutes
      )
    end

    result = @user.drive_sessions.activity_by_date(days: 28)
    assert_equal 5, result[5.days.ago.to_date]
  end

  # Reminder Job
  test "schedules reminder job when in-progress session is created" do
    # User needs a push subscription for reminder to be scheduled
    @user.push_subscriptions.create!(
      endpoint: "https://example.com/push",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_enqueued_jobs 1, only: DriveSessionReminderJob do
      @user.drive_sessions.create!(
        started_at: Time.current
      )
    end
  end

  test "does not schedule reminder job when completed session is created" do
    # User needs a push subscription for reminder to be scheduled
    @user.push_subscriptions.create!(
      endpoint: "https://example.com/push",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_no_enqueued_jobs only: DriveSessionReminderJob do
      @user.drive_sessions.create!(
        started_at: 1.hour.ago,
        ended_at: Time.current
      )
    end
  end

  test "does not schedule reminder job when user has no push subscriptions" do
    assert_no_enqueued_jobs only: DriveSessionReminderJob do
      @user.drive_sessions.create!(
        started_at: Time.current
      )
    end
  end

  # --- Derived statistics: hours ---
  test "day_hours excludes night drives" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    # is_night_drive is derived from the clock times below, not passed in.
    @user.drive_sessions.create!(started_at: tz.local(2026, 7, 6, 14, 0, 0), ended_at: tz.local(2026, 7, 6, 15, 0, 0)) # day, 1h
    @user.drive_sessions.create!(started_at: tz.local(2026, 7, 6, 21, 0, 0), ended_at: tz.local(2026, 7, 6, 22, 0, 0)) # night, 1h
    assert_in_delta 1.0, @user.drive_sessions.day_hours, 0.01
  end

  test "drives_count counts only completed drives" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(started_at: 2.hours.ago, ended_at: 1.hour.ago)
    @user.drive_sessions.create!(started_at: 30.minutes.ago) # in progress
    assert_equal 1, @user.drive_sessions.drives_count
  end

  test "hours_in_week sums the given calendar week (Sunday start) in the user timezone" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    travel_to Time.zone.parse("2026-07-15 12:00 UTC") do # Wed 2026-07-15
      # this week (Sun 07-12 .. Sat 07-18): one 1h drive
      @user.drive_sessions.create!(started_at: "2026-07-13 15:00", ended_at: "2026-07-13 16:00")
      # last week (Sun 07-05 .. Sat 07-11): one 2h drive
      @user.drive_sessions.create!(started_at: "2026-07-08 15:00", ended_at: "2026-07-08 17:00")
      assert_in_delta 1.0, @user.drive_sessions.hours_in_week(0, timezone: "America/Chicago"), 0.01
      assert_in_delta 2.0, @user.drive_sessions.hours_in_week(1, timezone: "America/Chicago"), 0.01
    end
  end

  # --- Derived statistics: streaks ---
  test "current_streak counts consecutive days ending today or yesterday" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    travel_to Time.zone.parse("2026-07-15 18:00 UTC") do # Wed 07-15
      [ "2026-07-13", "2026-07-14", "2026-07-15" ].each do |d|
        @user.drive_sessions.create!(started_at: "#{d} 15:00", ended_at: "#{d} 16:00")
      end
      assert_equal 3, @user.drive_sessions.current_streak(timezone: "America/Chicago")
    end
  end

  test "current_streak is zero when the last drive is older than yesterday" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    travel_to Time.zone.parse("2026-07-15 18:00 UTC") do
      @user.drive_sessions.create!(started_at: "2026-07-10 15:00", ended_at: "2026-07-10 16:00")
      assert_equal 0, @user.drive_sessions.current_streak(timezone: "America/Chicago")
    end
  end

  test "best_streak returns the longest consecutive run ever" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    [ "2026-06-01", "2026-06-02", "2026-06-03", "2026-06-10" ].each do |d|
      @user.drive_sessions.create!(started_at: "#{d} 15:00", ended_at: "#{d} 16:00")
    end
    assert_equal 3, @user.drive_sessions.best_streak(timezone: "America/Chicago")
  end

  test "active_day_count counts distinct active days within the trailing window" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    travel_to Time.zone.parse("2026-07-21 18:00 UTC") do
      @user.drive_sessions.create!(started_at: "2026-07-20 15:00", ended_at: "2026-07-20 16:00")
      @user.drive_sessions.create!(started_at: "2026-07-20 20:00", ended_at: "2026-07-20 21:00") # same day
      @user.drive_sessions.create!(started_at: "2026-06-01 15:00", ended_at: "2026-06-01 16:00") # outside 21d
      assert_equal 1, @user.drive_sessions.active_day_count(days: 21, timezone: "America/Chicago")
    end
  end

  # --- Derived statistics: pace & projection ---
  test "weekly_pace averages recent hours over weeks of history (capped at 4)" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    travel_to Time.zone.parse("2026-07-15 18:00 UTC") do
      # 15 days of history -> round(15/7)=2 weeks; 6 total recent hours -> 3.0/wk
      @user.drive_sessions.create!(started_at: "2026-07-01 15:00", ended_at: "2026-07-01 18:00") # 3h
      @user.drive_sessions.create!(started_at: "2026-07-14 15:00", ended_at: "2026-07-14 18:00") # 3h
      assert_in_delta 3.0, @user.drive_sessions.weekly_pace(timezone: "America/Chicago"), 0.1
    end
  end

  test "weekly_pace is zero with no drives" do
    @user.drive_sessions.destroy_all
    assert_equal 0.0, @user.drive_sessions.weekly_pace(timezone: "America/Chicago")
  end

  test "projected_finish returns a month label when on pace" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    travel_to Time.zone.parse("2026-07-15 18:00 UTC") do
      @user.drive_sessions.create!(started_at: "2026-07-01 15:00", ended_at: "2026-07-01 18:00")
      @user.drive_sessions.create!(started_at: "2026-07-14 15:00", ended_at: "2026-07-14 18:00")
      label = @user.drive_sessions.projected_finish(timezone: "America/Chicago")
      assert_match(/\A(Early|Mid|Late) [A-Z][a-z]+\z/, label)
    end
  end

  test "projected_finish is 'Keep driving' when pace is zero" do
    @user.drive_sessions.destroy_all
    assert_equal "Keep driving", @user.drive_sessions.projected_finish(timezone: "America/Chicago")
  end

  test "projected_finish is 'Complete' when the goal is met" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    @user.drive_sessions.create!(started_at: "2026-07-01 08:00", ended_at: "2026-07-03 10:00") # 50h
    assert_equal "Complete", @user.drive_sessions.projected_finish(timezone: "America/Chicago")
  end

  test "activity_day_states maps each active day to :day, :night, or :both" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    travel_to tz.local(2026, 7, 15, 18, 0, 0) do # Wed; grid window 06-28..07-18
      # is_night_drive is derived from the clock times, not passed in.
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 14, 14, 0, 0), ended_at: tz.local(2026, 7, 14, 15, 0, 0)) # day only
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 13, 21, 0, 0), ended_at: tz.local(2026, 7, 13, 22, 0, 0)) # night only
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 12, 14, 0, 0), ended_at: tz.local(2026, 7, 12, 15, 0, 0)) # day part of "both"
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 12, 21, 0, 0), ended_at: tz.local(2026, 7, 12, 22, 0, 0)) # night part of "both"
      states = @user.drive_sessions.activity_day_states(timezone: "America/Chicago")
      assert_equal :day,   states[Date.new(2026, 7, 14)]
      assert_equal :night, states[Date.new(2026, 7, 13)]
      assert_equal :both,  states[Date.new(2026, 7, 12)]
    end
  end
end
