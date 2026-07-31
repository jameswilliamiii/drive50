namespace :unforgettable do
  desc "Backfill night_minutes now that drives are split at sunset/sunrise"
  task release_20260729221806: :environment do
    # Every completed drive predates the night_minutes column, so each one is
    # reclassified from scratch. Totals move in both directions: drives that
    # merely clipped sunset lose the whole duration they were credited as night,
    # and drives taken between sunset and civil dusk gain the night credit they
    # never got. Reclassification uses the user's *current* coordinates, which is
    # the best signal available but means a drive logged before the user set
    # their location is judged against a different spot than it was originally.
    #
    # Only night_minutes is written. is_night_drive is left holding its old
    # civil-dusk values so that rolling the code back to the previous release
    # reproduces the numbers that were on screen before this deploy — rewriting it
    # here would make a rollback report a third, higher figure. Everything on this
    # release reads night_minutes instead.
    #
    # Safe to re-run: the value is derived, not accumulated.
    scope = DriveSession.completed.includes(:user)
    total = scope.count
    changed = 0
    failed = 0
    night_minutes_total = 0

    puts "Splitting day/night hours for #{total} completed drive(s)..."

    scope.find_each.with_index do |session, i|
      begin
        session.send(:determine_night_drive)
        # update_columns persists just the derived value, skipping validations and
        # the Turbo Stream broadcasts a mass reclassification would otherwise fire.
        if session.night_minutes_changed?
          session.update_columns(night_minutes: session.night_minutes)
          changed += 1
        end
        night_minutes_total += session.night_minutes
      rescue => e
        # One bad row must not truncate the run and leave the table half converted.
        failed += 1
        warn "  drive_session #{session.id}: #{e.class}: #{e.message}"
      end

      puts "  processed #{i + 1}/#{total}..." if ((i + 1) % 500).zero?
    end

    # Absolute state, not a delta, so a re-run after a partial failure reports
    # something an operator can actually compare against.
    puts "Night hours across all users: #{'%.1f' % (night_minutes_total / 60.0)} over #{total} drive(s)."
    puts "Rewrote #{changed} row(s) this run; #{failed} failed."

    # Raising leaves unforgettable_releases unwritten, so the task runs again on the
    # next deploy rather than silently declaring a partial backfill finished.
    raise "#{failed} drive(s) failed to backfill" if failed.positive?
  end
end
