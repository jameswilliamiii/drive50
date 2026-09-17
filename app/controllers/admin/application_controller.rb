module Admin
  class ApplicationController < Administrate::ApplicationController
    include Authentication

    around_action :use_central_time
    before_action :require_admin

    private
      def use_central_time(&block)
        Time.use_zone(User::DEFAULT_TIMEZONE, &block)
      end

      def require_admin
        return if Current.user&.admin?

        redirect_to root_path, alert: "You are not authorized to access that page."
      end
  end
end
