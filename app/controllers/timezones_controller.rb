class TimezonesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :update
  skip_before_action :require_authentication, only: :update

  def update
    timezone = params[:timezone]

    if timezone.present?
      session[:timezone] = timezone

      # Save to user if authenticated
      if authenticated? && Current.user.timezone != timezone
        Current.user.update_column(:timezone, timezone)
      end

      head :ok
    else
      head :unprocessable_entity
    end
  end
end
