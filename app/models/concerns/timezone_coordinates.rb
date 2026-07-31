module TimezoneCoordinates
  # Fallback coordinates for common US timezones
  # These are representative cities for each timezone
  TIMEZONE_COORDS = {
    # Eastern Time
    "America/New_York" => { lat: 40.7128, lon: -74.0060 },
    "America/Detroit" => { lat: 42.3314, lon: -83.0458 },
    "America/Kentucky/Louisville" => { lat: 38.2527, lon: -85.7585 },
    "America/Indiana/Indianapolis" => { lat: 39.7684, lon: -86.1581 },

    # Central Time
    "America/Chicago" => { lat: 41.8781, lon: -87.6298 },
    "America/Menominee" => { lat: 45.1077, lon: -87.6140 },
    "America/Indiana/Knox" => { lat: 41.2959, lon: -86.6250 },
    "America/North_Dakota/Center" => { lat: 47.1164, lon: -101.2996 },

    # Mountain Time
    "America/Denver" => { lat: 39.7392, lon: -104.9903 },
    "America/Boise" => { lat: 43.6150, lon: -116.2023 },
    "America/Phoenix" => { lat: 33.4484, lon: -112.0740 }, # No DST

    # Pacific Time
    "America/Los_Angeles" => { lat: 34.0522, lon: -118.2437 },
    "America/Seattle" => { lat: 47.6062, lon: -122.3321 },

    # Alaska Time
    "America/Anchorage" => { lat: 61.2181, lon: -149.9003 },
    "America/Juneau" => { lat: 58.3019, lon: -134.4197 },

    # Hawaii Time
    "Pacific/Honolulu" => { lat: 21.3099, lon: -157.8581 }
  }.freeze

  # Mid-northern latitude for zones we have no city for. Longitude carries the
  # seasonal signal; latitude only sets how extreme the swing is.
  FALLBACK_LATITUDE = 40.0

  def self.coordinates_for_timezone(timezone)
    TIMEZONE_COORDS[timezone] || meridian_coordinates(timezone)
  end

  # Longitude and UTC offset have to agree or the sunrise/sunset window is
  # nonsense: pairing a zero-offset zone with New York's -74° puts "sunset" after
  # local midnight, which reads as an inverted window and flags whole days wrong.
  # So for an unknown zone, place the driver on the meridian their clock is set to.
  def self.meridian_coordinates(timezone)
    zone = ActiveSupport::TimeZone[timezone.to_s]
    { lat: FALLBACK_LATITUDE, lon: (zone ? zone.utc_offset / 3600.0 : 0) * 15.0 }
  end
end
