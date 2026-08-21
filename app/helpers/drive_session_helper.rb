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

  DRIVE_KIND_ICONS = {
    day: :sun,
    night: :moon,
    mixed: :sunset
  }.freeze

  def drive_kind_label(drive)
    DRIVE_KIND_LABELS.fetch(drive.kind)
  end

  def drive_kind_icon(drive)
    DRIVE_KIND_ICONS.fetch(drive.kind)
  end

  # A badge that renders every kind at once and lets CSS pick needs all three
  # together, so they come from here rather than each caller reading the maps.
  def drive_kind_glyphs
    DRIVE_KIND_ICONS.map { |kind, glyph| [ kind, glyph, DRIVE_KIND_LABELS.fetch(kind) ] }
  end

  # "all" has no kind of its own, so it comes back without a glyph.
  def kind_filter_options
    DriveSession::KIND_FILTERS.map do |value|
      [ value, value.capitalize, DRIVE_KIND_ICONS[value.to_sym] ]
    end
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
