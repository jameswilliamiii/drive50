class WebPushService
  class ConfigurationError < StandardError; end

  class << self
    # Send a push notification to a specific user (async via job)
    #
    # @param user [User] The user to send the notification to
    # @param title [String] The notification title
    # @param body [String] The notification body text
    # @param url [String] The URL to open when the notification is clicked (optional)
    # @param options [Hash] Additional notification options (optional)
    # @return [Boolean] true if job was enqueued, false otherwise
    #
    # Example:
    #   WebPushService.notify_user(
    #     user,
    #     "Drive Complete!",
    #     "Great job! You completed a 30-minute drive session.",
    #     url: "/drive_sessions"
    #   )
    def notify_user(user, title, body, url: nil, **options)
      return false unless user.push_subscriptions.exists?

      validate_params!(title, body)

      WebPushJob.perform_later(
        user_ids: [ user.id ],
        title: title,
        body: body,
        url: url,
        options: options
      )
      true
    end

    # Send a push notification to multiple users (async via job)
    #
    # @param users [ActiveRecord::Relation, Array<User>] Users to notify
    # @param title [String] The notification title
    # @param body [String] The notification body text
    # @param url [String] The URL to open when the notification is clicked (optional)
    # @param options [Hash] Additional notification options (optional)
    # @return [Boolean] true if job was enqueued, false otherwise
    def notify_users(users, title, body, url: nil, **options)
      user_ids = users.is_a?(ActiveRecord::Relation) ? users.pluck(:id) : users.map(&:id)
      return false if user_ids.empty?

      validate_params!(title, body)

      WebPushJob.perform_later(
        user_ids: user_ids,
        title: title,
        body: body,
        url: url,
        options: options
      )
      true
    end

    # Validate VAPID credentials are configured
    #
    # @raise [ConfigurationError] if VAPID keys are missing
    def validate_configuration!
      public_key = Rails.application.credentials.dig(:vapid, :public_key)
      private_key = Rails.application.credentials.dig(:vapid, :private_key)

      if public_key.blank? || private_key.blank?
        raise ConfigurationError, "VAPID keys not configured in credentials"
      end
    end

    private

    def validate_params!(title, body)
      raise ArgumentError, "title cannot be blank" if title.blank?
      raise ArgumentError, "body cannot be blank" if body.blank?
    end
  end
end
