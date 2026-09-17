class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  ONBOARDING_LEAVE_CONTROLLERS = %w[
    drive_sessions
    users
    pages
    registrations
  ].freeze

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set user's timezone for the request so Rails parses datetimes correctly
  before_action :set_time_zone
  before_action :clear_onboarding_if_left, if: :authenticated?

  helper_method :offer_push_prompt?

  def offer_push_prompt?
    return @offer_push_prompt if defined?(@offer_push_prompt)
    @offer_push_prompt = session.delete(:offer_push_prompt) == true
  end

  private

  def clear_onboarding_if_left
    return unless session[:show_onboarding]
    return if controller_path == "onboarding"
    # Brakeman VerbConfusion: HEAD shares GET routes but request.get? is false.
    return unless request.get? || request.head?
    return unless ONBOARDING_LEAVE_CONTROLLERS.include?(controller_path)

    session.delete(:show_onboarding)
  end

  def set_time_zone
    # Get timezone from params (form submission or AJAX) or session or user
    timezone = params[:timezone] || session[:timezone] || (Current.user&.timezone if authenticated?)

    if timezone.present?
      Time.zone = timezone
      session[:timezone] = timezone

      # Save timezone to user if authenticated and timezone changed
      if authenticated? && Current.user.timezone != timezone
        Current.user.update_column(:timezone, timezone)
      end
    end
  end
end
