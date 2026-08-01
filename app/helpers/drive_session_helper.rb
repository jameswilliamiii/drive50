module DriveSessionHelper
  include DurationFormatting

  # The one place the day/night wording lives. The drive row's screen-reader label
  # and the detail modal's heading render from this, so they cannot drift — they
  # already had, "Day and night drive" against "Day & night drive".
  DRIVE_KIND_LABELS = {
    day: "Day drive",
    night: "Night drive",
    mixed: "Day & night drive"
  }.freeze

  def drive_kind_label(drive)
    DRIVE_KIND_LABELS.fetch(drive.kind)
  end

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
