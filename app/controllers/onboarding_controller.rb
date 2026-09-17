class OnboardingController < ApplicationController
  before_action :require_onboarding_session

  def location; end
  def push; end

  def save_location
    if Current.user.update(location_params)
      redirect_to onboarding_push_path
    else
      render :location, status: :unprocessable_content
    end
  end

  def finish
    clear_onboarding_session!
    redirect_to root_path, notice: "Welcome! Your account has been created."
  end

  private
    def require_onboarding_session
      return if session[:show_onboarding]

      redirect_to root_path
    end

    def clear_onboarding_session!
      session.delete(:show_onboarding)
    end

    def location_params
      params.require(:user).permit(:latitude, :longitude)
    end
end
