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

  test "format_duration pluralizes both units" do
    # The unstyled branch used to hardcode "hrs"/"mins", so a 1h45m day summary
    # read "1 hrs 45 mins".
    assert_equal "1 hr 45 mins", format_duration(1.75)
    assert_equal "2 hrs 1 min", format_duration(2 + 1 / 60.0)
    assert_equal "1 min", format_duration(1 / 60.0)
    assert_equal "1 hr", format_duration(1.0)
  end
end
