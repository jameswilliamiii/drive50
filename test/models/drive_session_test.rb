require "test_helper"

class DriveSessionTest < ActiveSupport::TestCase
  test "calculates duration on save" do
    session = DriveSession.create!(
      driver_name: "Test Driver",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )

    assert_equal 60, session.duration_minutes
  end

  test "determines night drive based on start time" do
    # Night drive
    night_session = DriveSession.create!(
      driver_name: "Test Driver",
      started_at: Time.current.change(hour: 21),
      ended_at: Time.current.change(hour: 22)
    )
    assert night_session.is_night_drive

    # Day drive
    day_session = DriveSession.create!(
      driver_name: "Test Driver",
      started_at: Time.current.change(hour: 14),
      ended_at: Time.current.change(hour: 15)
    )
    assert_not day_session.is_night_drive
  end

  test "requires driver name" do
    session = DriveSession.new(started_at: Time.current)
    assert_not session.valid?
    assert_includes session.errors[:driver_name], "can't be blank"
  end

  test "calculates total hours" do
    DriveSession.create!(
      driver_name: "Test",
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )

    # Allow for small rounding differences
    assert_in_delta 1.0, DriveSession.total_hours, 0.1
  end
end
