require "test_helper"

class DriveSessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

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

  # Chicago sunset/sunrise used by the split tests below (exact coords), as the
  # model itself computes them:
  #   Dec 15 — sunrise 07:11, sunset 16:20 CST   (Dec 16 sunrise 07:12)
  #   Jul  1 — sunrise 05:18, sunset 20:29 CDT   (civil dusk 21:03)
  # Dates are pinned, so the expected minute counts are exact — a loose tolerance
  # here would swallow a systematic shift in the solar math.
  test "splits a drive that crosses sunset into day and night minutes" do
    session = chicago_drive(2024, 12, 15, from: "16:00", to: "17:00")

    assert_equal 40, session.night_minutes, "only the post-sunset portion is night"
    assert_equal 60, session.duration_minutes
    assert session.any_night?, "a drive containing any night is flagged"
  end

  test "counts a drive between sunset and civil dusk as night" do
    # Regression: night used to begin at civil dusk (~33 min after sunset), so a
    # drive taken entirely in that window was credited as day hours.
    session = chicago_drive(2026, 7, 1, from: "20:40", to: "21:00")

    assert_equal 20, session.night_minutes
    assert session.any_night?
  end

  test "splits a drive that crosses sunrise into day and night minutes" do
    session = chicago_drive(2024, 12, 15, from: "06:00", to: "08:00")

    assert_equal 71, session.night_minutes, "only the pre-sunrise portion is night"
  end

  test "an overnight drive stops earning night credit at the next morning's sunrise" do
    # 22:00 → 09:00 next day. Sunrise on Dec 16 is 07:12, so 552 min dark, 108 light.
    session = chicago_drive(2024, 12, 15, from: "22:00", to: "33:00")

    assert_equal 660, session.duration_minutes
    assert_equal 552, session.night_minutes
  end

  test "splits a multi-day drive at every sunrise and sunset it spans" do
    # 48 hours starting mid-morning: two full nights plus the tail of day three.
    session = chicago_drive(2024, 12, 15, from: "10:00", to: "58:00")

    assert_equal 2880, session.duration_minutes
    assert_equal 1785, session.night_minutes
  end

  test "night is the wrapped window where the sun sets after local midnight" do
    # Above ~64°N in early summer the sun sets just after midnight and rises a few
    # hours later, so sunset precedes sunrise on the same date. Bailing out of that
    # window instead of classifying it erased real night driving.
    @user.update!(timezone: "America/Anchorage", latitude: 64.8378, longitude: -147.7164) # Fairbanks
    tz = ActiveSupport::TimeZone.new("America/Anchorage")

    dark = @user.drive_sessions.create!(
      started_at: tz.local(2026, 6, 1, 1, 0, 0),   # sunset was 00:06
      ended_at: tz.local(2026, 6, 1, 3, 0, 0)      # sunrise is 03:31
    )
    assert_equal 120, dark.night_minutes, "01:00-03:00 in Fairbanks in June is dark"

    noon = @user.drive_sessions.create!(
      started_at: tz.local(2026, 6, 1, 12, 0, 0),
      ended_at: tz.local(2026, 6, 1, 13, 0, 0)
    )
    assert_equal 0, noon.night_minutes, "midday on the same date is not night"
  end

  test "splits correctly across the day where an inverted window meets a normal one" do
    # Fairbanks' wrapped window ends on 2026-07-14. Without local midnight as a cut
    # point the segment from that day's sunrise to the next day's ran ~24h and was
    # judged by a single midpoint, crediting the daylight half as night.
    @user.update!(timezone: "America/Anchorage", latitude: 64.8378, longitude: -147.7164)
    tz = ActiveSupport::TimeZone.new("America/Anchorage")

    session = @user.drive_sessions.create!(
      started_at: tz.local(2026, 7, 14, 23, 0, 0),
      ended_at: tz.local(2026, 7, 15, 1, 0, 0)
    )

    assert_equal 120, session.duration_minutes
    assert_equal 60, session.night_minutes, "was 120 — the whole drive credited as night"
  end

  test "an over-long drive that already exists stays editable" do
    session = @user.drive_sessions.create!(started_at: 2.hours.ago, ended_at: 1.hour.ago)
    session.update_columns(
      started_at: 30.days.ago, ended_at: 20.days.ago, duration_minutes: 14_400
    )

    assert session.reload.update(notes: "logged late"), session.errors.full_messages.to_sentence
  end

  test "solar events use the offset in effect after a DST change" do
    # Reading the offset at local midnight instead of noon shifts every event by an
    # hour on transition days, which flips drives near sunrise for every US user.
    # Reading it at midnight would put sunrise at 06:14 (0 night minutes here)...
    spring = chicago_drive(2026, 3, 8, from: "06:30", to: "07:30") # sunrise 07:14 CDT
    assert_equal 44, spring.night_minutes

    # ...and sunset at 17:44, clipping this drive to 16 night minutes.
    fall = chicago_drive(2026, 11, 1, from: "17:00", to: "18:00")  # sunset 16:44 CST
    assert_equal 60, fall.night_minutes
  end

  test "a user with no timezone at all is judged in UTC" do
    @user.update!(timezone: nil, latitude: nil, longitude: nil)

    session = @user.drive_sessions.create!(
      started_at: Time.utc(2026, 7, 1, 22, 0, 0),
      ended_at: Time.utc(2026, 7, 1, 23, 0, 0)
    )

    assert_equal 60, session.night_minutes
  end

  test "an unresolvable timezone falls back instead of raising" do
    # timezones#update writes whatever the browser posts, unvalidated.
    @user.update_column(:timezone, "Not/AZone")
    @user.reload

    session = nil
    assert_nothing_raised do
      session = @user.drive_sessions.create!(
        started_at: Time.utc(2026, 7, 1, 22, 0, 0),
        ended_at: Time.utc(2026, 7, 1, 23, 0, 0)
      )
    end
    assert_equal 60, session.night_minutes
  end

  test "day and night hours reconcile with duration when minutes divide unevenly" do
    # The CSV's three columns are totalled by whoever receives the log, so they have
    # to add up. Rounding each of the three independently leaves ~22% of pairs off
    # by a cent — here 0.42 + 0.42 = 0.84 against a duration of 0.83.
    session = @user.drive_sessions.new(duration_minutes: 50, night_minutes: 25)

    assert_equal 0.83, session.duration_hours
    assert_equal 0.42, session.night_hours
    assert_equal 0.41, session.day_hours
    assert_equal session.duration_hours, session.day_hours + session.night_hours
  end

  test "night minutes never exceed the recorded duration" do
    # duration_minutes truncates; night_minutes used to round, which put a wholly
    # dark drive with a seconds remainder one minute over and made day_hours negative.
    session = chicago_drive(2024, 12, 15, from: "22:00", to: "23:00", end_seconds: 54)

    assert_equal 60, session.duration_minutes
    assert_equal 60, session.night_minutes
    assert_equal 0.0, session.day_hours
  end

  test "night minutes are capped when recomputed against a duration nobody refreshed" do
    # The backfill calls calculate_night_minutes directly, without calculate_duration,
    # so it can meet a row whose stored duration predates an edit. The cap is what
    # keeps day_hours from going negative on those rows.
    session = chicago_drive(2024, 12, 15, from: "22:00", to: "23:00")
    session.update_column(:duration_minutes, 20) # stale, as if an old edit left it

    session.reload.send(:calculate_night_minutes)

    assert_equal 20, session.night_minutes
    assert_equal 0.0, session.day_hours
  end

  test "editing only the start time recomputes duration alongside night minutes" do
    session = chicago_drive(2024, 12, 15, from: "16:00", to: "17:00")
    tz = ActiveSupport::TimeZone.new("America/Chicago")

    session.update!(started_at: tz.local(2024, 12, 15, 4, 0, 0))
    session.reload

    assert_equal 780, session.duration_minutes, "duration must follow the new span"
    assert_operator session.day_hours, :>=, 0
    assert_operator session.night_minutes, :<=, session.duration_minutes
    assert_in_delta session.duration_hours, session.day_hours + session.night_hours, 0.001
  end

  test "rejects a drive longer than the maximum" do
    session = @user.drive_sessions.new(
      started_at: Time.current,
      ended_at: Time.current + DriveSession::MAX_DRIVE_DURATION + 1.minute
    )

    assert_not session.valid?
    assert_includes session.errors[:ended_at].join, "7 days"
  end

  test "credits a wholly-nighttime drive entirely to night" do
    session = chicago_drive(2024, 12, 15, from: "22:00", to: "23:00")

    assert_equal 60, session.night_minutes
    assert session.any_night?
  end

  test "credits a wholly-daytime drive entirely to day" do
    session = chicago_drive(2024, 12, 15, from: "12:00", to: "13:00")

    assert_equal 0, session.night_minutes
    assert_not session.any_night?
  end

  test "an in-progress drive has no night minutes until it ends" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")

    session = @user.drive_sessions.create!(started_at: tz.local(2024, 12, 15, 22, 0, 0))
    assert_equal 0, session.night_minutes, "nothing is credited until there is a span to split"

    session.update!(ended_at: tz.local(2024, 12, 15, 23, 0, 0))
    assert_equal 60, session.night_minutes
  end

  test "midday drives at high latitude are day drives" do
    # Regression for the civil-dusk threshold: civil dusk falls after local midnight
    # in Anchorage each summer, which inverted the window and flagged every daytime
    # drive as night. Official sunset never inverts here — the wrapped-window branch
    # itself is covered by the Fairbanks test above.
    @user.update!(timezone: "America/Anchorage", latitude: 61.2181, longitude: -149.9003)
    tz = ActiveSupport::TimeZone.new("America/Anchorage")

    session = @user.drive_sessions.create!(
      started_at: tz.local(2026, 6, 1, 12, 0, 0),
      ended_at: tz.local(2026, 6, 1, 13, 0, 0)
    )

    assert_equal 0, session.night_minutes
    assert_not session.any_night?, "noon in Anchorage in June is not night"
  end

  test "statistics credit only the night portion of a crossing drive" do
    @user.drive_sessions.destroy_all
    chicago_drive(2024, 12, 15, from: "16:00", to: "17:00")

    stats = DriveSession.statistics_for(@user, timezone: "America/Chicago")

    assert_in_delta 1.0, stats[:total_hours], 0.01
    assert_in_delta 40 / 60.0, stats[:night_hours], 0.05
    assert_in_delta 20 / 60.0, stats[:day_hours], 0.05
  end

  test "a crossing drive is grouped onto its local date" do
    @user.drive_sessions.destroy_all
    # The calendar only covers the last three weeks, so sit inside that window.
    travel_to ActiveSupport::TimeZone.new("America/Chicago").local(2024, 12, 15, 23, 0, 0) do
      session = chicago_drive(2024, 12, 15, from: "16:00", to: "17:00")
      days = @user.drive_sessions.activity_days(timezone: "America/Chicago")
      date = session.started_at.in_time_zone("America/Chicago").to_date

      assert_equal [ session ], days[date], "the crossing drive lands on its start date"
    end
  end

  test "determines night drive based on sunset/sunrise times in winter" do
    # Set user timezone and location (Chicago)
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    tz = ActiveSupport::TimeZone.new("America/Chicago")

    # 5pm drive in winter should be night (after sunset)
    night_session = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 17, 0, 0),
      ended_at: tz.local(2024, 12, 15, 18, 0, 0)
    )
    assert night_session.any_night?, "5pm in winter should be night drive"

    # 2pm drive in winter should be day (before sunset)
    day_session = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 14, 0, 0),
      ended_at: tz.local(2024, 12, 15, 15, 0, 0)
    )
    assert_not day_session.any_night?, "2pm in winter should be day drive"
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
      assert_not noon.any_night?, "noon in #{zone} (summer) should be a day drive"
    end
  end

  test "determines night drive for early morning" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    night_session = @user.drive_sessions.create!(
      started_at: Time.current.change(hour: 2),
      ended_at: Time.current.change(hour: 3)
    )
    assert night_session.any_night?, "Early morning should be night drive"
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
    assert night_session.any_night?, "Should use timezone fallback coordinates"
  end

  test "handles polar regions where the sun never sets" do
    @user.update!(timezone: "UTC", latitude: 89.0, longitude: 0.0) # Near North Pole

    # With no sunrise/sunset to split on, the drive is credited as day rather
    # than raising or guessing.
    session = nil
    assert_nothing_raised do
      session = @user.drive_sessions.create!(
        started_at: Time.utc(2024, 6, 15, 12, 0, 0),
        ended_at: Time.utc(2024, 6, 15, 13, 0, 0)
      )
    end

    assert_equal 0, session.night_minutes
    assert_not session.any_night?
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


  test "with_day and with_night both return a drive that crossed sunset" do
    @user.drive_sessions.destroy_all
    day = chicago_drive(2024, 12, 15, from: "12:00", to: "13:00")
    night = chicago_drive(2024, 12, 15, from: "18:00", to: "19:00")
    mixed = chicago_drive(2024, 12, 15, from: "16:00", to: "17:00")
    assert_equal [ :day, :night, :mixed ], [ day.kind, night.kind, mixed.kind ]

    assert_equal [ day, mixed ].sort, @user.drive_sessions.with_day.sort
    assert_equal [ night, mixed ].sort, @user.drive_sessions.with_night.sort
  end

  test "matching_kind falls back to the full relation for anything but day or night" do
    @user.drive_sessions.destroy_all
    day = chicago_drive(2024, 12, 15, from: "12:00", to: "13:00")
    night = chicago_drive(2024, 12, 15, from: "18:00", to: "19:00")
    all = [ day, night ].sort

    assert_equal [ day ], @user.drive_sessions.matching_kind("day")
    assert_equal [ night ], @user.drive_sessions.matching_kind("night")
    assert_equal all, @user.drive_sessions.matching_kind("all").sort
    assert_equal all, @user.drive_sessions.matching_kind(nil).sort
    assert_equal all, @user.drive_sessions.matching_kind("bogus").sort
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

    assert_in_delta 2.0, DriveSession.statistics_for(@user)[:total_hours], 0.1
  end

  test "night_hours calculates total night hours" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)

    tz = ActiveSupport::TimeZone.new("America/Chicago")
    @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 21, 0, 0),
      ended_at: tz.local(2024, 12, 15, 22, 0, 0)
    )

    assert_in_delta 1.0, DriveSession.statistics_for(@user, timezone: "America/Chicago")[:night_hours], 0.1
  end

  test "hours_needed returns remaining hours" do
    # Create sessions totaling 45 hours
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      started_at: 45.hours.ago,
      ended_at: Time.current
    )

    assert_in_delta 5.0, DriveSession.statistics_for(@user)[:hours_needed], 0.1
  end

  test "hours_needed returns 0 when requirement is met" do
    # Create sessions totaling more than 50 hours
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(
      started_at: 51.hours.ago,
      ended_at: Time.current
    )

    assert_equal 0, DriveSession.statistics_for(@user)[:hours_needed]
  end

  test "night_hours_needed returns remaining night hours" do
    @user.drive_sessions.destroy_all
    # 9pm to 2am in mid-December: dark end to end, so all 5 hours count.
    chicago_drive(2024, 12, 15, from: "21:00", to: "26:00")

    assert_in_delta 5.0, DriveSession.statistics_for(@user, timezone: "America/Chicago")[:night_hours_needed], 0.1
  end

  test "night_hours_needed returns 0 when requirement is met" do
    @user.drive_sessions.destroy_all
    # 5pm to 7am spans sunset and stops just shy of sunrise (07:10): 14 hours,
    # all of them dark, which clears the 10-hour requirement.
    chicago_drive(2024, 12, 15, from: "17:00", to: "31:00")

    assert_equal 0, DriveSession.statistics_for(@user, timezone: "America/Chicago")[:night_hours_needed]
  end

  test "an overnight drive stops earning night credit at sunrise" do
    @user.drive_sessions.destroy_all
    # 5am to 9am on Dec 15: dark until sunrise at 07:10, daylight after.
    chicago_drive(2024, 12, 15, from: "05:00", to: "09:00")

    stats = DriveSession.statistics_for(@user, timezone: "America/Chicago")
    assert_in_delta 2.18, stats[:night_hours], 0.01
    assert_in_delta 1.82, stats[:day_hours], 0.01
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
    # The split is derived from the clock times below, not passed in.
    @user.drive_sessions.create!(started_at: tz.local(2026, 7, 6, 14, 0, 0), ended_at: tz.local(2026, 7, 6, 15, 0, 0)) # day, 1h
    @user.drive_sessions.create!(started_at: tz.local(2026, 7, 6, 21, 0, 0), ended_at: tz.local(2026, 7, 6, 22, 0, 0)) # night, 1h

    assert_in_delta 1.0, DriveSession.statistics_for(@user, timezone: "America/Chicago")[:day_hours], 0.01
  end

  test "drives_count counts only completed drives" do
    @user.drive_sessions.destroy_all
    @user.drive_sessions.create!(started_at: 2.hours.ago, ended_at: 1.hour.ago)
    @user.drive_sessions.create!(started_at: 30.minutes.ago) # in progress
    assert_equal 1, DriveSession.statistics_for(@user)[:drives_count]
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

  test "the broadcast rebuilds a grid that still carries the day's drives" do
    # The only broadcast coverage was assert_nothing_raised, which proves the
    # stream does not throw — not that the grid it re-renders is correct. The
    # grid could go blank on every live update and stay green.
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    @user.drive_sessions.destroy_all
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    today = Time.current.in_time_zone(tz).to_date

    stream = Turbo::StreamsChannel.send(:stream_name_from, @user)
    payloads = capture_broadcasts(stream) do
      @user.drive_sessions.create!(
        started_at: tz.local(today.year, today.month, today.day, 14),
        ended_at: tz.local(today.year, today.month, today.day, 15)
      )
    end

    grid = payloads.map(&:to_s).find { |html| html.include?("activity-cell") }
    assert grid, "a broadcast should re-render the Momentum grid"

    summaries = Nokogiri::HTML5.fragment(grid).css("button.activity-cell")
                               .map { |node| JSON.parse(node["data-day-summary"]) }
    assert summaries.any? { |s| s["count"] == 1 && s["total"] == "1 hr" },
           "the rebuilt grid must carry the drive that triggered it"
  end

  test "activity_days spans exactly the 21 cells the grid renders" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    @user.drive_sessions.destroy_all

    travel_to tz.local(2026, 7, 15, 18, 0, 0) do # Wed; window 06-28..07-18
      first_cell = @user.drive_sessions.create!(
        started_at: tz.local(2026, 6, 28, 0, 0, 0), ended_at: tz.local(2026, 6, 28, 1, 0, 0)
      )
      too_early = @user.drive_sessions.create!(
        started_at: tz.local(2026, 6, 27, 23, 0, 0), ended_at: tz.local(2026, 6, 27, 23, 59, 59)
      )
      too_late = @user.drive_sessions.create!(
        started_at: tz.local(2026, 7, 19, 0, 0, 0), ended_at: tz.local(2026, 7, 19, 1, 0, 0)
      )

      # Assert on the loaded set rather than a date key: what this pins is the
      # query's bounds, not which cell the drive happens to land in.
      loaded = @user.drive_sessions.activity_days(timezone: "America/Chicago").values.flatten

      assert_includes loaded, first_cell, "midnight of the first cell is inside the window"
      assert_not_includes loaded, too_early, "the day before the grid is outside"
      assert_not_includes loaded, too_late, "the day after the grid is outside"
    end
  end

  test "activity_days groups drives by their local date" do
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    travel_to tz.local(2026, 7, 15, 18, 0, 0) do # Wed; grid window 06-28..07-18
      # The split is derived from the clock times, not passed in.
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 14, 14, 0, 0), ended_at: tz.local(2026, 7, 14, 15, 0, 0)) # day only
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 13, 21, 0, 0), ended_at: tz.local(2026, 7, 13, 22, 0, 0)) # night only
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 12, 14, 0, 0), ended_at: tz.local(2026, 7, 12, 15, 0, 0)) # day part of "both"
      @user.drive_sessions.create!(started_at: tz.local(2026, 7, 12, 21, 0, 0), ended_at: tz.local(2026, 7, 12, 22, 0, 0)) # night part of "both"
      days = @user.drive_sessions.activity_days(timezone: "America/Chicago")

      assert_equal 1, days[Date.new(2026, 7, 14)].size
      assert_equal 1, days[Date.new(2026, 7, 13)].size
      assert_equal 2, days[Date.new(2026, 7, 12)].size, "both drives land on the same local day"
      assert_nil days[Date.new(2026, 7, 11)], "a day with no drives is absent"
    end
  end

  private

  # Hours past 24 roll into the next day so overnight drives read naturally:
  # from "21:00" to "26:00" is 9pm to 2am.
  def chicago_drive(year, month, day, from:, to:, end_seconds: 0)
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    at = ->(hhmm, seconds) do
      hours, minutes = hhmm.split(":").map(&:to_i)
      date = Date.new(year, month, day) + (hours / 24)
      tz.local(date.year, date.month, date.day, hours % 24, minutes, seconds)
    end

    @user.drive_sessions.create!(started_at: at.call(from, 0), ended_at: at.call(to, end_seconds))
  end
end
