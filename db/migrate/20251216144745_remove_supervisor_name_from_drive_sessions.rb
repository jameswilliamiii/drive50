class RemoveSupervisorNameFromDriveSessions < ActiveRecord::Migration[8.1]
  def change
    remove_column :drive_sessions, :supervisor_name, :string
  end
end
