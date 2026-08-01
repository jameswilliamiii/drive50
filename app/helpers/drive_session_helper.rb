module DriveSessionHelper
  include DurationFormatting

  # Time-of-day greeting in the user's own timezone, personalized when we know
  # their name.
  def dashboard_greeting(user)
    tz = DriveSession.resolved_zone(user.timezone)
    part = case Time.current.in_time_zone(tz).hour
    when 5..11 then "Good morning"
    when 12..16 then "Good afternoon"
    else "Good evening"
    end
    user.first_name.present? ? "#{part}, #{user.first_name}" : part
  end
end
