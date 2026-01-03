class WebPushJob < ApplicationJob
  queue_as :default

  # Retry on rate limiting with exponential backoff
  retry_on WebPush::ResponseError, wait: :exponentially_longer, attempts: 3 do |job, error|
    # Log final failure after all retries
    Rails.logger.error "WebPushJob failed after #{job.executions} attempts: #{error.message}"
  end

  def perform(user_ids:, title:, body:, url: nil, options: {})
    subscriptions = PushSubscription.where(user_id: user_ids)

    return if subscriptions.none?

    payload = build_payload(title, body, url, options)

    success_count = 0
    failure_count = 0

    subscriptions.find_each do |subscription|
      result = send_notification(subscription, payload)
      result ? success_count += 1 : failure_count += 1

      # Throttle to avoid rate limiting (adjust based on push service limits)
      sleep 0.1 if subscriptions.count > 10
    end

    Rails.logger.info "Push notifications sent: #{success_count} succeeded, #{failure_count} failed"
  end

  private

  def build_payload(title, body, url, options)
    {
      title: title,
      body: body,
      icon: options[:icon] || "/icons/icon-192x192.png",
      badge: options[:badge] || "/icons/icon-192x192.png",
      data: {
        url: url || "/"
      }.merge(options[:data] || {}),
      tag: options[:tag],
      requireInteraction: options[:require_interaction] || false,
      actions: options[:actions] || []
    }.compact.to_json
  end

  def send_notification(subscription, payload)
    WebPush.payload_send(
      message: payload,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: vapid_credentials
    )

    # Mark subscription as active on successful send
    subscription.mark_as_active!
    true
  rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription => e
    # Subscription is no longer valid, remove it
    Rails.logger.warn "Removing invalid push subscription #{subscription.id}: #{e.message}"
    subscription.destroy
    false
  rescue WebPush::ResponseError => e
    # Handle HTTP errors from push service
    if e.response.code.to_i == 429
      Rails.logger.error "Rate limited by push service"
      raise # Re-raise to trigger retry
    else
      Rails.logger.error "Push service error (#{e.response.code}): #{e.message}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "Failed to send push notification: #{e.class}: #{e.message}"
    false
  end

  def vapid_credentials
    {
      subject: vapid_subject,
      public_key: Rails.application.credentials.dig(:vapid, :public_key),
      private_key: Rails.application.credentials.dig(:vapid, :private_key)
    }
  end

  def vapid_subject
    if Rails.env.production?
      Rails.application.credentials.dig(:vapid, :subject) || "mailto:noreply@drive50.app"
    else
      "mailto:noreply@localhost"
    end
  end
end
