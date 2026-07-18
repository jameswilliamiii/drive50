class RemoveDriverNameFromDriveSessions < ActiveRecord::Migration[8.1]
  def change
    # driver_name was a denormalized copy of the owning user's name and is now
    # derived from the association. On rollback the column comes back nullable
    # (not null: false) — the original values are gone by design, so re-adding a
    # NOT NULL column with no data would fail on a populated table anyway.
    remove_column :drive_sessions, :driver_name, :string
  end
end
