class AddNightMinutesToDriveSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :drive_sessions, :night_minutes, :integer, default: 0, null: false
  end
end
