# Clear existing data
DriveSession.destroy_all
User.destroy_all

# Create sample user with Chicago timezone
user = User.create!(
  name: "Sarah Mitchell",
  email_address: "jameswilliamiii@gmail.com",
  password: "password",
  password_confirmation: "password",
  timezone: "America/Chicago"
)

# Set timezone for creating drive sessions
Time.zone = "America/Chicago"

# Create some completed drives
20.times do |i|
  days_ago = rand(1..60)
  # Create times in Chicago timezone
  start_time = Time.zone.now - days_ago.days
  start_time = start_time.change(hour: rand(8..20), min: [ 0, 15, 30, 45 ].sample)
  duration = [ 30, 45, 60, 90, 120 ].sample
  end_time = start_time + duration.minutes

  user.drive_sessions.create!(
    driver_name: user.name, # Automatically set to user's name
    started_at: start_time.utc, # Convert to UTC for storage
    ended_at: end_time.utc, # Convert to UTC for storage
    notes: [
      "Highway practice, lane changes",
      "Neighborhood streets, stop signs",
      "Parking practice at mall",
      "Rush hour traffic experience",
      nil, nil # Some without notes
    ].sample
  )
end

puts "Created user: #{user.name} (#{user.email_address})"
puts "Created #{DriveSession.count} drive sessions"
total_hours = user.drive_sessions.completed.sum(:duration_minutes) / 60.0
night_hours = user.drive_sessions.night_drives.completed.sum(:duration_minutes) / 60.0
puts "Total hours: #{total_hours.round(1)}"
puts "Night hours: #{night_hours.round(1)}"
