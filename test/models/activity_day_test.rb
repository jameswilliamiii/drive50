require "test_helper"

class ActivityDayTest < ActiveSupport::TestCase
  setup do
    @tz = ActiveSupport::TimeZone.new("America/Chicago")
    @user = users(:one)
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    @user.drive_sessions.destroy_all
  end

  test "grid_for returns 21 Sunday-aligned cells with today and future flags" do
    travel_to @tz.local(2026, 7, 15, 18, 0, 0) do # Wed
      cells = ActivityDay.grid_for({}, timezone: "America/Chicago")

      assert_equal 21, cells.length
      assert_equal 0, cells.first.date.wday, "the grid starts on a Sunday"
      assert_equal Date.new(2026, 6, 28), cells.first.date
      assert_equal Date.new(2026, 7, 18), cells.last.date
      assert_equal Date.new(2026, 7, 15), cells.find(&:today?).date
      assert_equal 3, cells.count(&:future?), "Thu-Sat of the current week"
    end
  end

  test "state reflects whether the day holds daylight driving, night driving, or both" do
    travel_to @tz.local(2026, 7, 15, 18, 0, 0) do
      day = drive("2026-07-14 14:00", "2026-07-14 15:00")
      night = drive("2026-07-13 21:00", "2026-07-13 22:00")
      crossing = drive("2026-07-12 19:30", "2026-07-12 21:00") # straddles sunset

      assert_equal :day, cell_for(Date.new(2026, 7, 14), [ day ]).state
      assert_equal :night, cell_for(Date.new(2026, 7, 13), [ night ]).state
      assert_equal :both, cell_for(Date.new(2026, 7, 12), [ crossing ]).state,
                   "one drive can colour a day both ways once it crosses sunset"
      assert_equal :both, cell_for(Date.new(2026, 7, 11), [ day, night ]).state
      assert_equal :none, cell_for(Date.new(2026, 7, 10), []).state
    end
  end

  test "a drive too short to credit a minute still colours its day" do
    # Reachable: ended_at > started_at passes validation while duration_minutes
    # truncates to 0. Leaving it :none painted the cell empty while the same cell
    # announced "1 drive" and opened a summary.
    travel_to @tz.local(2026, 7, 15, 18, 0, 0) do
      brief = drive("2026-07-14 14:00:00", "2026-07-14 14:00:20")

      assert_equal 0, brief.duration_minutes
      cell = cell_for(Date.new(2026, 7, 14), [ brief ])
      assert_equal :day, cell.state
      assert cell.any_drives?
    end
  end

  test "state tolerates a drive with no recorded duration" do
    # Same rule as the zero-minute case above: a drive is present, so the day is
    # coloured rather than left blank. The point is that it does not raise.
    assert_equal :day, cell_for(Date.current, [ DriveSession.new(night_minutes: 0) ]).state
  end

  test "aria_label names the day, its drive count, and its total" do
    travel_to @tz.local(2026, 7, 15, 18, 0, 0) do
      one = drive("2026-07-14 14:00", "2026-07-14 15:00")
      two = drive("2026-07-14 21:00", "2026-07-14 22:00")

      assert_equal "July 14, no drives", cell_for(Date.new(2026, 7, 14), []).aria_label
      assert_equal "July 14, 1 drive, 1 hr", cell_for(Date.new(2026, 7, 14), [ one ]).aria_label
      assert_equal "July 14, 2 drives, 2 hrs", cell_for(Date.new(2026, 7, 14), [ one, two ]).aria_label
    end
  end

  test "as_json carries what the day-summary modal renders" do
    travel_to @tz.local(2026, 7, 15, 18, 0, 0) do
      crossing = drive("2026-07-14 19:30", "2026-07-14 21:00")
      payload = cell_for(Date.new(2026, 7, 14), [ crossing ]).as_json

      assert_equal "Tuesday, July 14, 2026", payload[:label]
      assert_equal 1, payload[:count]
      assert_equal "1 hr 30 mins", payload[:total]
      assert payload[:day], "a crossing drive contributes to both totals"
      assert payload[:night]
      assert_equal "mixed", payload[:drives].first[:kind].to_s
      # Formatted in the cell's own zone, so the heading and the rows can never
      # describe different local days.
      assert_equal "7:30 PM – 9:00 PM", payload[:drives].first[:time]
    end
  end

  test "a day with only daylight driving omits the night total rather than reporting zero" do
    travel_to @tz.local(2026, 7, 15, 18, 0, 0) do
      payload = cell_for(Date.new(2026, 7, 14), [ drive("2026-07-14 14:00", "2026-07-14 15:00") ]).as_json

      assert_equal "1 hr", payload[:day]
      assert_nil payload[:night]
    end
  end

  test "a driveless day reports no drives and no totals" do
    payload = cell_for(Date.current, []).as_json

    assert_equal 0, payload[:count]
    assert_empty payload[:drives]
    assert_nil payload[:day]
    assert_nil payload[:night]
  end

  private

  def drive(from, to)
    parse = ->(s) { @tz.parse(s) }
    @user.drive_sessions.create!(started_at: parse.call(from), ended_at: parse.call(to))
  end

  def cell_for(date, drives)
    ActivityDay.new(date: date, drives: drives, today: Date.new(2026, 7, 15), zone: @tz)
  end
end
