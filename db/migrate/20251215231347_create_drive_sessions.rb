class CreateDriveSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :drive_sessions do |t|
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_minutes
      t.boolean :is_night_drive, default: false, null: false
      t.text :notes
      t.string :supervisor_name
      t.string :driver_name, null: false

      t.timestamps
    end

    add_index :drive_sessions, :started_at
    add_index :drive_sessions, :ended_at
  end
end
