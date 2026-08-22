class ChangeDefaultTimezoneOnUsers < ActiveRecord::Migration[8.1]
  def change
    # See User::DEFAULT_TIMEZONE. Only changes the default for rows inserted
    # from here on — existing users keep whatever they already have.
    change_column_default :users, :timezone, from: "UTC", to: "America/Chicago"
  end
end
