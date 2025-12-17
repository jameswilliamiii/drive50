require "test_helper"

class DriveSessionTest < ActiveSupport::TestCase
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

  test "determines night drive based on start time" do
    # Night drive
    night_session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
      started_at: Time.current.change(hour: 21),
      ended_at: Time.current.change(hour: 22)
    )
    assert night_session.is_night_drive

    # Day drive
    day_session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
      started_at: Time.current.change(hour: 14),
      ended_at: Time.current.change(hour: 15)
    )
    assert_not day_session.is_night_drive
  end

  test "determines night drive for early morning" do
    night_session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
      started_at: Time.current.change(hour: 2),
      ended_at: Time.current.change(hour: 3)
    )
    assert night_session.is_night_drive
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
    night = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: Time.current.change(hour: 21),
      ended_at: Time.current.change(hour: 22)
    )
    day = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: Time.current.change(hour: 14),
      ended_at: Time.current.change(hour: 15)
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
    @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: Time.current.change(hour: 21),
      ended_at: Time.current.change(hour: 22)
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
end
