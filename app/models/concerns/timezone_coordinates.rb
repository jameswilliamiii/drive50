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
    "Pacific/Honolulu" => { lat: 21.3099, lon: -157.8581 },

    # Default fallback (New York)
    "UTC" => { lat: 40.7128, lon: -74.0060 }
  }.freeze

  def self.coordinates_for_timezone(timezone)
    TIMEZONE_COORDS[timezone] || TIMEZONE_COORDS["UTC"]
  end
end
