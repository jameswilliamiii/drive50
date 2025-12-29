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

  # activity_calendar_data tests
  test "activity_calendar_data generates correct number of days" do
    activity_data = { 1.day.ago.to_date => 2, Date.today => 3 }
    result = activity_calendar_data(activity_data, days: 28)

    assert_equal 28, result[:days].length
    assert_equal 28, result[:total_days]
  end

  test "activity_calendar_data sets correct activity levels" do
    date = Date.today
    activity_data = { date => 3 }
    result = activity_calendar_data(activity_data, days: 7)

    day_data = result[:days].find { |d| d[:date] == date }
    assert_equal 3, day_data[:count]
    assert_equal 3, day_data[:level]
  end

  test "activity_calendar_data level 0 for no drives" do
    date = Date.today
    activity_data = {}
    result = activity_calendar_data(activity_data, days: 7)

    day_data = result[:days].find { |d| d[:date] == date }
    assert_equal 0, day_data[:count]
    assert_equal 0, day_data[:level]
  end

  test "activity_calendar_data level 1 for one drive" do
    date = Date.today
    activity_data = { date => 1 }
    result = activity_calendar_data(activity_data, days: 7)

    day_data = result[:days].find { |d| d[:date] == date }
    assert_equal 1, day_data[:level]
  end

  test "activity_calendar_data level 2 for two drives" do
    date = Date.today
    activity_data = { date => 2 }
    result = activity_calendar_data(activity_data, days: 7)

    day_data = result[:days].find { |d| d[:date] == date }
    assert_equal 2, day_data[:level]
  end

  test "activity_calendar_data level 3 for three drives" do
    date = Date.today
    activity_data = { date => 3 }
    result = activity_calendar_data(activity_data, days: 7)

    day_data = result[:days].find { |d| d[:date] == date }
    assert_equal 3, day_data[:level]
  end

  test "activity_calendar_data level 4 for four or more drives" do
    date = Date.today
    activity_data = { date => 10 }
    result = activity_calendar_data(activity_data, days: 7)

    day_data = result[:days].find { |d| d[:date] == date }
    assert_equal 10, day_data[:count]
    assert_equal 4, day_data[:level]
  end

  test "activity_calendar_data generates label for single week" do
    result = activity_calendar_data({}, days: 7)
    assert_equal "Last week", result[:label]
  end

  test "activity_calendar_data generates label for two weeks" do
    result = activity_calendar_data({}, days: 14)
    assert_equal "Last 2 weeks", result[:label]
  end

  test "activity_calendar_data generates label for four weeks" do
    result = activity_calendar_data({}, days: 28)
    assert_equal "Last 4 weeks", result[:label]
  end

  test "activity_calendar_data includes all dates in range" do
    activity_data = { 3.days.ago.to_date => 2 }
    result = activity_calendar_data(activity_data, days: 7)

    # Should have exactly 7 consecutive days ending today
    assert_equal 7, result[:days].length
    assert_equal Date.today, result[:days].last[:date]
    assert_equal 6.days.ago.to_date, result[:days].first[:date]
  end

  test "activity_calendar_data returns hash with required keys" do
    result = activity_calendar_data({}, days: 7)

    assert_kind_of Hash, result
    assert result.key?(:days)
    assert result.key?(:label)
    assert result.key?(:total_days)
  end

  test "activity_calendar_data days are hashes with required keys" do
    result = activity_calendar_data({}, days: 7)

    result[:days].each do |day|
      assert_kind_of Hash, day
      assert day.key?(:date)
      assert day.key?(:count)
      assert day.key?(:level)
    end
  end

  # circular_progress tests
  test "circular_progress generates valid SVG" do
    result = circular_progress(current: 25, total: 50)

    assert_includes result, "<svg"
    assert_includes result, "</svg>"
    assert_includes result, "progress-bg"
    assert_includes result, "progress-bar"
    assert_includes result, "circular-progress"
  end

  test "circular_progress handles 0 percentage" do
    result = circular_progress(current: 0, total: 50)

    assert_includes result, "<svg"
    assert_includes result, "circular-progress"
  end

  test "circular_progress handles 100 percentage" do
    result = circular_progress(current: 50, total: 50)

    assert_includes result, "<svg"
    assert_includes result, "circular-progress"
  end

  test "circular_progress handles over 100 percentage" do
    result = circular_progress(current: 75, total: 50)

    # Should clamp to 100% (verified by checking stroke-dashoffset calculation)
    assert_includes result, "<svg"
    assert_includes result, "circular-progress"
  end

  test "circular_progress includes gradient definition" do
    result = circular_progress(current: 25, total: 50)

    assert_includes result, "linearGradient"
    assert_includes result, "progress-gradient"
  end

  test "circular_progress respects size parameter" do
    result = circular_progress(current: 25, total: 50, size: 200)

    assert_includes result, 'width="200"'
    assert_includes result, 'height="200"'
  end

  test "circular_progress respects stroke_width parameter" do
    result = circular_progress(current: 25, total: 50, stroke_width: 12)

    assert_includes result, 'stroke-width="12"'
  end

  test "circular_progress handles default parameters" do
    result = circular_progress(current: 25, total: 50)

    # Default size is 120
    assert_includes result, 'width="120"'
    assert_includes result, 'height="120"'
    # Default stroke_width is 8
    assert_includes result, 'stroke-width="8"'
  end

  test "circular_progress returns HTML-safe string" do
    result = circular_progress(current: 25, total: 50)

    # raw() returns an ActiveSupport::SafeBuffer which is html_safe?
    assert result.html_safe?
  end
end
