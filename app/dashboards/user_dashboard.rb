require "administrate/base_dashboard"

class UserDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    admin: Field::Boolean,
    drive_sessions: Field::HasMany,
    email_address: Field::String,
    first_name: Field::String,
    hours_goal: Field::Number,
    last_name: Field::String,
    latitude: Field::String.with_options(searchable: false),
    longitude: Field::String.with_options(searchable: false),
    night_hours_goal: Field::Number,
    password: Field::Password,
    password_confirmation: Field::Password,
    push_subscriptions: Field::HasMany,
    sessions: Field::HasMany,
    timezone: Field::String,
    weekly_motivation_enabled: Field::Boolean,
    weekly_motivation_sent_on: Field::Date,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    first_name
    last_name
    email_address
    admin
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    first_name
    last_name
    email_address
    admin
    hours_goal
    night_hours_goal
    timezone
    weekly_motivation_enabled
    weekly_motivation_sent_on
    latitude
    longitude
    drive_sessions
    sessions
    push_subscriptions
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    first_name
    last_name
    email_address
    password
    password_confirmation
    admin
    hours_goal
    night_hours_goal
    timezone
    latitude
    longitude
    weekly_motivation_enabled
    weekly_motivation_sent_on
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(user)
    user.full_name.presence || user.email_address
  end
end
