# Clear existing data
DriveSession.destroy_all

# Create sample driver
driver_name = "Sarah Mitchell"

# Create some completed drives
20.times do |i|
  days_ago = rand(1..60)
  start_time = days_ago.days.ago.change(hour: rand(8..20), min: [ 0, 15, 30, 45 ].sample)
  duration = [ 30, 45, 60, 90, 120 ].sample
  end_time = start_time + duration.minutes

  DriveSession.create!(
    driver_name: driver_name,
    supervisor_name: [ "Mom", "Dad", "Uncle Tom", "Aunt Jane" ].sample,
    started_at: start_time,
    ended_at: end_time,
    notes: [
      "Highway practice, lane changes",
      "Neighborhood streets, stop signs",
      "Parking practice at mall",
      "Rush hour traffic experience",
      nil, nil # Some without notes
    ].sample
  )
end

puts "Created #{DriveSession.count} drive sessions"
puts "Total hours: #{DriveSession.total_hours.round(1)}"
puts "Night hours: #{DriveSession.night_hours.round(1)}"
