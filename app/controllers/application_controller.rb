class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set user's timezone for the request so Rails parses datetimes correctly
  before_action :set_time_zone
  # Set request variant based on device type
  before_action :set_variant

  helper_method :mobile_device?

  private

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

  def set_variant
    request.variant = :mobile if mobile_device?
  end

  def mobile_device?
    browser.device.mobile? || browser.device.tablet?
  end
end
