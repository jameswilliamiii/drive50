class AddHourGoalsToUsers < ActiveRecord::Migration[8.1]
  def change
    # A common state requirement (50 hours, 10 at night) — hardcoded rather
    # than referencing DriveSession::HOURS_NEEDED, since a migration has to
    # stay correct even if that constant changes or goes away.
    add_column :users, :hours_goal, :integer, null: false, default: 50
    add_column :users, :night_hours_goal, :integer, null: false, default: 10
  end
end
