require "test_helper"

class DriveSessionHelperTest < ActionView::TestCase
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

  test "format_duration pluralizes both units" do
    # The unstyled branch used to hardcode "hrs"/"mins", so a 1h45m day summary
    # read "1 hrs 45 mins".
    assert_equal "1 hr 45 mins", format_duration(1.75)
    assert_equal "2 hrs 1 min", format_duration(2 + 1 / 60.0)
    assert_equal "1 min", format_duration(1 / 60.0)
    assert_equal "1 hr", format_duration(1.0)
  end

  test "format_duration_short drops the empty half rather than padding it" do
    assert_equal "1h 45m", format_duration_short(1.75)
    assert_equal "2h", format_duration_short(2.0)
    assert_equal "45m", format_duration_short(0.75)
  end

  test "format_duration_short reports zero in hours, not minutes" do
    assert_equal "0h", format_duration_short(nil)
    assert_equal "0h", format_duration_short(0)
  end

  test "format_duration_short marks up its units so the row can tone them down" do
    result = format_duration_short(1.75, style_units: true)

    assert_equal "1<span class='unit'>h</span> 45<span class='unit'>m</span>", result
    assert_predicate result, :html_safe?
  end

  test "format_duration_short marks up a zero and a single-unit duration too" do
    assert_equal "0<span class='unit'>h</span>", format_duration_short(0, style_units: true)
    assert_equal "2<span class='unit'>h</span>", format_duration_short(2.0, style_units: true)
    assert_equal "45<span class='unit'>m</span>", format_duration_short(0.75, style_units: true)
  end

  test "every styled branch is html_safe, or the row prints its own markup" do
    # A drive under 30 seconds truncates to zero minutes and still renders a row.
    [ 0, nil, -0.5, 2.0, 1.75, 0.75 ].each do |hours|
      assert_predicate format_duration_short(hours, style_units: true), :html_safe?,
                       "format_duration_short(#{hours.inspect}, style_units: true)"
    end
  end

  test "a negative duration reports zero rather than wrapping into a positive one" do
    # -0.5 divmods to [-1, 30]; unclamped that renders "30m", a negative half hour
    # shown as a positive one. -1.0 lands on [-1, 0] and misses the wrap entirely.
    assert_equal "0h", format_duration_short(-0.5)
    assert_equal "0 hrs", format_duration(-1.5)
    assert_equal "0 hours", format_duration_spoken(-0.5)
  end

  test "format_duration_spoken spells the units out for labels that are announced" do
    assert_equal "2 hours 30 minutes", format_duration_spoken(2.5)
    assert_equal "1 hour", format_duration_spoken(1.0)
    assert_equal "1 minute", format_duration_spoken(1 / 60.0)
    assert_equal "0 hours", format_duration_spoken(0)
  end
end
