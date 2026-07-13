namespace :unforgettable do
  desc "Backfill is_night_drive after the sunset/sunrise date-bug fix"
  task release_20260713135049: :environment do
    scope = DriveSession.completed.includes(:user)
    total = scope.count
    changed = 0

    puts "Recomputing night-drive flag for #{total} completed drive(s)..."

    scope.find_each.with_index do |session, i|
      session.send(:determine_night_drive)

      if session.is_night_drive_changed?
        # update_column persists just the flag without firing callbacks/broadcasts.
        session.update_column(:is_night_drive, session.is_night_drive)
        changed += 1
      end

      puts "  processed #{i + 1}/#{total}..." if ((i + 1) % 500).zero?
    end

    puts "Done. Updated #{changed} of #{total} drive(s)."
  end
end
