class RemoveIsNightDriveFromDriveSessions < ActiveRecord::Migration[8.1]
  # Superseded by night_minutes. The column was kept through the sunset-split
  # release so a rollback would still find pre-split values; that release is
  # deployed and settled, and nothing has read the column since.
  #
  # Reversible in shape only: `down` restores the column with its default, not the
  # values, so rolling back past the split release would report the wrong night
  # hours. Re-running the backfill would not help either — it writes night_minutes.
  def change
    remove_column :drive_sessions, :is_night_drive, :boolean, default: false, null: false
  end
end
