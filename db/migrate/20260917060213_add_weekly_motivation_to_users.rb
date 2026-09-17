class AddWeeklyMotivationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :weekly_motivation_enabled, :boolean, default: true, null: false
    add_column :users, :weekly_motivation_sent_on, :date
  end
end
