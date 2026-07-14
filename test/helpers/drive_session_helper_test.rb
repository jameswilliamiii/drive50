require "test_helper"

class DriveSessionHelperTest < ActionView::TestCase
  # format_duration tests
  test "format_duration handles nil" do
    assert_equal "0 hrs", format_duration(nil)
  end

  test "format_duration handles zero" do
    assert_equal "0 hrs", format_duration(0)
  end

  test "format_duration formats hours only" do
    assert_equal "2 hrs", format_duration(2.0)
  end

  test "format_duration formats single hour" do
    assert_equal "1 hr", format_duration(1.0)
  end

  test "format_duration formats hours and minutes" do
    assert_equal "2 hrs 30 mins", format_duration(2.5)
  end

  test "format_duration formats minutes only" do
    assert_equal "45 mins", format_duration(0.75)
  end

  test "format_duration rounds minutes" do
    # 0.76 hours = 45.6 minutes, should round to 46
    assert_equal "46 mins", format_duration(0.76)
  end

  test "format_duration with style_units wraps units in spans" do
    result = format_duration(2.5, style_units: true)
    assert_includes result, "<span class='unit'>hrs</span>"
    assert_includes result, "<span class='unit'>mins</span>"
    assert_includes result, "2"
    assert_includes result, "30"
  end

  test "format_duration with style_units for single hour" do
    result = format_duration(1.0, style_units: true)
    assert_includes result, "<span class='unit'>hr</span>"
    assert_includes result, "1"
  end

  test "format_duration with style_units for multiple hours" do
    result = format_duration(3.0, style_units: true)
    assert_includes result, "<span class='unit'>hrs</span>"
    assert_includes result, "3"
  end

  test "format_duration with style_units for minutes only" do
    result = format_duration(0.5, style_units: true)
    assert_includes result, "<span class='unit'>mins</span>"
    assert_includes result, "30"
  end

  test "format_duration with style_units for zero" do
    result = format_duration(0, style_units: true)
    assert_includes result, "<span class='unit'>hrs</span>"
    assert_includes result, "0"
  end

  # dashboard_activity_days tests
  test "dashboard_activity_days returns 21 Sunday-aligned cells with today and future flags" do
    travel_to Time.zone.parse("2026-07-15 18:00 UTC") do # Wed
      states = { Date.new(2026, 7, 14) => :day }
      days = dashboard_activity_days(states, timezone: "America/Chicago")
      assert_equal 21, days.length
      assert_equal 0, days.first[:date].wday # first cell is a Sunday
      assert(days.any? { |d| d[:today] })
      today_cell = days.find { |d| d[:today] }
      assert_equal Date.new(2026, 7, 15), today_cell[:date]
      assert_equal :day, days.find { |d| d[:date] == Date.new(2026, 7, 14) }[:state]
      assert(days.any? { |d| d[:future] }) # Thu-Sat of current week
    end
  end
end
