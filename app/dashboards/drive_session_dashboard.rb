require "administrate/base_dashboard"

class DriveSessionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    duration_minutes: Field::Number,
    ended_at: Field::DateTime,
    night_minutes: Field::Number,
    notes: Field::Text,
    started_at: Field::DateTime,
    user: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    user
    started_at
    duration_minutes
    night_minutes
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    user
    started_at
    ended_at
    duration_minutes
    night_minutes
    notes
    created_at
    updated_at
  ].freeze

  # duration_minutes and night_minutes are recomputed from started_at/ended_at — keep them off the form.
  FORM_ATTRIBUTES = %i[
    user
    started_at
    ended_at
    notes
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(drive_session)
    "Drive ##{drive_session.id}"
  end
end
