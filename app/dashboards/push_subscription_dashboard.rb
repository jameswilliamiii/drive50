require "administrate/base_dashboard"

class PushSubscriptionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    auth_key: Field::String,
    endpoint: Field::String,
    p256dh_key: Field::String,
    user: Field::BelongsTo,
    user_agent: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    user
    endpoint
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    user
    endpoint
    user_agent
    auth_key
    p256dh_key
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    user
    endpoint
    user_agent
    auth_key
    p256dh_key
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(push_subscription)
    "Push Subscription ##{push_subscription.id}"
  end
end
