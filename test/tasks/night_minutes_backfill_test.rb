require "test_helper"
require "rake"

# Covers lib/tasks/unforgettable/release_20260729221806.rake. The task writes with
# update_columns across every completed drive, so a regression here silently
# rewrites the whole table with no validation and no broadcast to notice it.
class NightMinutesBackfillTest < ActiveSupport::TestCase
  TASK = "unforgettable:release_20260729221806".freeze

  setup do
    @user = users(:one)
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    @user.drive_sessions.destroy_all

    # Rake.application is process-global and these tests run in a forked worker
    # shared with every other test file, so it has to go back the way it was.
    @previous_rake = Rake.application
    Rake.application = Rake::Application.new
    # The empty third argument is the "already loaded" list: rake_require defaults
    # it to $", which would skip the reload on every test after the first.
    Rake.application.rake_require("unforgettable/release_20260729221806", [ Rails.root.join("lib/tasks").to_s ], [])
    Rake::Task.define_task(:environment)
  end

  teardown do
    Rake.application = @previous_rake
  end

  test "recomputes the split for drives left at the column default" do
    drive = completed_drive_on_dec_15("16:00", "17:00")
    drive.update_columns(night_minutes: 0, is_night_drive: true) # pre-backfill state

    run_task

    assert_equal 40, drive.reload.night_minutes
  end

  test "leaves the legacy is_night_drive flag untouched so a rollback is clean" do
    # A midday drive the old civil-dusk rule had flagged as night: night_minutes
    # must drop to 0 while the flag keeps its old value, so rolling back to the
    # previous release reproduces the pre-deploy totals rather than a third number.
    drive = completed_drive_on_dec_15("12:00", "13:00")
    drive.update_columns(night_minutes: 60, is_night_drive: true)

    run_task

    drive.reload
    assert_equal 0, drive.night_minutes
    assert drive.is_night_drive, "the backfill must not rewrite the legacy flag"
  end

  test "a failing row does not truncate the run, and the task raises so it retries" do
    completed_drive_on_dec_15("16:00", "17:00")
    completed_drive_on_dec_15("22:00", "23:00")
    DriveSession.any_instance.stubs(:determine_night_drive).raises(ArgumentError, "boom")

    error = assert_raises(RuntimeError) { run_task }

    # Both rows are counted, so the first failure did not abort the loop; raising
    # leaves unforgettable_releases unwritten so the next deploy tries again.
    assert_equal "2 drive(s) failed to backfill", error.message
  end

  test "leaves in-progress drives alone" do
    drive = @user.drive_sessions.create!(started_at: chicago.local(2024, 12, 15, 22, 0, 0))

    run_task

    drive.reload
    assert_nil drive.ended_at
    assert_equal 0, drive.night_minutes
  end

  test "is idempotent" do
    drive = completed_drive_on_dec_15("16:00", "17:00")
    drive.update_columns(night_minutes: 0, is_night_drive: false)

    run_task
    first = drive.reload.night_minutes

    run_task
    assert_equal first, drive.reload.night_minutes
  end

  test "does not raise on a user whose timezone is missing or unresolvable" do
    @user.update_columns(timezone: nil, latitude: nil, longitude: nil)
    completed_drive_on_dec_15("16:00", "17:00")

    assert_nothing_raised { run_task }

    @user.update_column(:timezone, "Not/AZone")
    assert_nothing_raised { run_task }
  end

  private

  def chicago
    ActiveSupport::TimeZone.new("America/Chicago")
  end

  def completed_drive_on_dec_15(from, to)
    parse = ->(hhmm) { chicago.local(2024, 12, 15, *hhmm.split(":").map(&:to_i)) }
    @user.drive_sessions.create!(started_at: parse.call(from), ended_at: parse.call(to))
  end

  def run_task
    task = Rake::Task[TASK]
    task.reenable
    capture_io { task.invoke }
  end
end
