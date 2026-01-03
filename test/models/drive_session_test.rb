require "test_helper"

class DriveSessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
  end

  # Validations
  test "requires driver name" do
    session = @user.drive_sessions.new(started_at: Time.current)
    assert_not session.valid?
    assert_includes session.errors[:driver_name], "can't be blank"
  end

  test "requires started_at" do
    session = @user.drive_sessions.new(driver_name: "Test Driver")
    assert_not session.valid?
    assert_includes session.errors[:started_at], "can't be blank"
  end

  test "requires ended_at to be after started_at" do
    session = @user.drive_sessions.new(
      driver_name: "Test Driver",
      started_at: Time.current,
      ended_at: 1.hour.ago
    )
    assert_not session.valid?
    assert_includes session.errors[:ended_at], "must be after start time"
  end

  # Calculations
  test "calculates duration on save" do
    session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
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
      driver_name: "Test Driver",
      started_at: tz.local(2024, 12, 15, 17, 0, 0),
      ended_at: tz.local(2024, 12, 15, 18, 0, 0)
    )
    assert night_session.is_night_drive, "5pm in winter should be night drive"

    # 2pm drive in winter should be day (before sunset)
    day_session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
      started_at: tz.local(2024, 12, 15, 14, 0, 0),
      ended_at: tz.local(2024, 12, 15, 15, 0, 0)
    )
    assert_not day_session.is_night_drive, "2pm in winter should be day drive"
  end

  test "determines night drive for early morning" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    night_session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
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
      driver_name: "Test Driver",
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
    session = @user.drive_sessions.new(driver_name: "Test")

    # This should not raise an error
    assert_nothing_raised do
      result = session.send(:night_time?, time, 89.0, 0.0)
      assert_equal false, result
    end
  end

  test "duration_hours returns 0 for nil duration" do
    session = @user.drive_sessions.new(driver_name: "Test", started_at: Time.current)
    assert_equal 0, session.duration_hours
  end

  test "duration_hours converts minutes to hours" do
    session = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 2.hours.ago,
      ended_at: Time.current
    )
    assert_in_delta 2.0, session.duration_hours, 0.1
  end

  # Scopes
  test "completed scope returns only completed sessions" do
    completed = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    in_progress = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: Time.current
    )

    assert_includes @user.drive_sessions.completed, completed
    assert_not_includes @user.drive_sessions.completed, in_progress
  end

  test "in_progress scope returns only in-progress sessions" do
    completed = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    in_progress = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: Time.current
    )

    assert_includes @user.drive_sessions.in_progress, in_progress
    assert_not_includes @user.drive_sessions.in_progress, completed
  end

  test "night_drives scope returns only night drives" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    tz = ActiveSupport::TimeZone.new("America/Chicago")

    night = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: tz.local(2024, 12, 15, 21, 0, 0),
      ended_at: tz.local(2024, 12, 15, 22, 0, 0)
    )
    day = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: tz.local(2024, 12, 15, 14, 0, 0),
      ended_at: tz.local(2024, 12, 15, 15, 0, 0)
    )

    assert_includes @user.drive_sessions.night_drives, night
    assert_not_includes @user.drive_sessions.night_drives, day
  end

  test "ordered scope returns sessions in reverse chronological order" do
    @user.drive_sessions.destroy_all
    first = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 3.hours.ago,
      ended_at: 2.hours.ago
    )
    second = @user.drive_sessions.create!(
      driver_name: "Test",
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
      driver_name: "Test",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    assert session.completed?
  end

  test "completed? returns false when ended_at is nil" do
    session = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: Time.current
    )
    assert_not session.completed?
  end

  test "in_progress? returns true when ended_at is nil" do
    session = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: Time.current
    )
    assert session.in_progress?
  end

  test "in_progress? returns false when ended_at is present" do
    session = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    assert_not session.in_progress?
  end

  test "elapsed_time returns formatted time for in-progress session" do
    session = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 30.minutes.ago
    )
    assert_match(/\d+m/, session.elapsed_time)
  end

  test "elapsed_time returns nil for completed session" do
    session = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )
    assert_nil session.elapsed_time
  end

  # Class methods
  test "total_hours calculates total completed hours" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )
    @user.drive_sessions.create!(
      driver_name: "Test",
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
      driver_name: "Test",
      started_at: tz.local(2024, 12, 15, 21, 0, 0),
      ended_at: tz.local(2024, 12, 15, 22, 0, 0)
    )

    assert_in_delta 1.0, @user.drive_sessions.night_hours, 0.1
  end

  test "hours_needed returns remaining hours" do
    # Create sessions totaling 45 hours
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 45.hours.ago,
      ended_at: Time.current
    )

    assert_in_delta 5.0, @user.drive_sessions.hours_needed, 0.1
  end

  test "hours_needed returns 0 when requirement is met" do
    # Create sessions totaling more than 50 hours
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 51.hours.ago,
      ended_at: Time.current
    )

    assert_equal 0, @user.drive_sessions.hours_needed
  end

  test "night_hours_needed returns remaining night hours" do
    @user.drive_sessions.destroy_all
    # Create a 5-hour night drive (9pm to 2am)
    @user.drive_sessions.create!(
      driver_name: "Test",
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
      driver_name: "Test",
      started_at: yesterday.change(hour: 21),
      ended_at: yesterday.tomorrow.change(hour: 8)
    )

    assert_equal 0, @user.drive_sessions.night_hours_needed
  end

  # Statistics
  test "statistics_for returns all statistics" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      driver_name: "Test",
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
          driver_name: "Test",
          started_at: 2.days.ago.beginning_of_day + 10.hours,
          ended_at: 2.days.ago.beginning_of_day + 11.hours
        )
      end

      2.times do
        @user.drive_sessions.create!(
          driver_name: "Test",
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
      driver_name: "Test",
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

    # Completed drive
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 1.day.ago,
      ended_at: 1.day.ago + 1.hour
    )

    # In-progress drive
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 1.day.ago
    )

    result = @user.drive_sessions.activity_by_date(days: 28)
    assert_equal 1, result[1.day.ago.to_date]
  end

  test "activity_by_date filters by date range" do
    @user.drive_sessions.destroy_all

    # Drive within range (10 days ago)
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 10.days.ago,
      ended_at: 10.days.ago + 1.hour
    )

    # Drive outside range (40 days ago)
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 40.days.ago,
      ended_at: 40.days.ago + 1.hour
    )

    result = @user.drive_sessions.activity_by_date(days: 28)
    assert_equal 1, result.values.sum
  end

  test "activity_by_date handles nil timezone gracefully" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      driver_name: "Test",
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
        driver_name: "Test",
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
        driver_name: "Test",
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
        driver_name: "Test",
        started_at: 1.hour.ago,
        ended_at: Time.current
      )
    end
  end

  test "does not schedule reminder job when user has no push subscriptions" do
    assert_no_enqueued_jobs only: DriveSessionReminderJob do
      @user.drive_sessions.create!(
        driver_name: "Test",
        started_at: Time.current
      )
    end
  end
end
