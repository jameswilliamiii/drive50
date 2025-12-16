class AddUserToDriveSessions < ActiveRecord::Migration[8.1]
  def change
    # First, delete existing drive sessions since they don't belong to any user
    execute "DELETE FROM drive_sessions"

    # Now add the user reference (add_reference automatically creates an index)
    add_reference :drive_sessions, :user, null: false, foreign_key: true
  end
end
