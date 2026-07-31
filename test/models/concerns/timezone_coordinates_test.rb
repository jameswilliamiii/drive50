require "test_helper"

class TimezoneCoordinatesTest < ActiveSupport::TestCase
  test "returns the mapped city for a known timezone" do
    coords = TimezoneCoordinates.coordinates_for_timezone("America/Chicago")

    assert_in_delta 41.8781, coords[:lat], 0.001
    assert_in_delta(-87.6298, coords[:lon], 0.001)
  end

  test "places an unmapped timezone on the meridian matching its offset" do
    # Regression: every unmapped zone used to fall back to New York's longitude,
    # so a zone with a different offset got a sunrise/sunset window that could
    # invert and misclassify entire days.
    assert_in_delta 0.0, TimezoneCoordinates.coordinates_for_timezone("UTC")[:lon], 0.001
    assert_in_delta(-75.0, TimezoneCoordinates.coordinates_for_timezone("America/Toronto")[:lon], 0.001)
    assert_in_delta 15.0, TimezoneCoordinates.coordinates_for_timezone("Europe/Berlin")[:lon], 0.001
  end

  test "handles zones whose offset is not a whole hour" do
    # Integer division would floor these to 75.0 and -60.0 — a ~30-minute error in
    # sunrise and sunset for every sub-hour zone.
    assert_in_delta 82.5, TimezoneCoordinates.coordinates_for_timezone("Asia/Kolkata")[:lon], 0.001
    assert_in_delta(-52.5, TimezoneCoordinates.coordinates_for_timezone("America/St_Johns")[:lon], 0.001)
  end

  test "falls back to the prime meridian for an unparseable timezone" do
    coords = TimezoneCoordinates.coordinates_for_timezone("Not/AZone")

    assert_in_delta 0.0, coords[:lon], 0.001
    assert_in_delta TimezoneCoordinates::FALLBACK_LATITUDE, coords[:lat], 0.001
  end

  test "a UTC drive after dark is a night drive" do
    # The New York fallback made this drive look like daylight in summer.
    user = users(:one)
    user.update!(timezone: "UTC", latitude: nil, longitude: nil)

    session = user.drive_sessions.create!(
      started_at: Time.utc(2026, 7, 1, 22, 0, 0),
      ended_at: Time.utc(2026, 7, 1, 23, 0, 0)
    )

    assert_equal 60, session.night_minutes
  end
end
