class PushSubscriptionsController < ApplicationController
  before_action :require_authentication

  def new
    public_key = Rails.application.credentials.dig(:vapid, :public_key)

    if public_key.blank?
      render json: { error: "Push notifications not configured" }, status: :service_unavailable
    else
      render json: { public_key: public_key }
    end
  end

  def create
    subscription_params = params.require(:subscription).permit(:endpoint, keys: [ :p256dh, :auth ])

    return render_invalid_endpoint unless valid_endpoint?(subscription_params[:endpoint])

    @push_subscription = Current.user.push_subscriptions.find_or_initialize_by(
      endpoint: subscription_params[:endpoint]
    )

    @push_subscription.assign_attributes(
      p256dh_key: subscription_params.dig(:keys, :p256dh),
      auth_key: subscription_params.dig(:keys, :auth),
      user_agent: sanitized_user_agent
    )

    if @push_subscription.save
      Rails.logger.info "Push subscription created for user #{Current.user.id} from #{request.remote_ip}"
      render json: { success: true }, status: :created
    else
      Rails.logger.warn "Failed to create push subscription for user #{Current.user.id}: #{@push_subscription.errors.full_messages}"
      render json: { errors: @push_subscription.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    endpoint = params.require(:endpoint)

    return render_invalid_endpoint unless valid_endpoint?(endpoint)

    subscription = Current.user.push_subscriptions.find_by(endpoint: endpoint)

    if subscription&.destroy
      Rails.logger.info "Push subscription deleted for user #{Current.user.id}"
      head :no_content
    else
      render json: { error: "Subscription not found" }, status: :not_found
    end
  end

  private
    def valid_endpoint?(endpoint)
      return false if endpoint.blank?

      uri = URI.parse(endpoint)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    def render_invalid_endpoint
      render json: { error: "Invalid endpoint URL" }, status: :unprocessable_content
    end

    def sanitized_user_agent
      request.user_agent&.truncate(500, omission: "...")
    end
end
