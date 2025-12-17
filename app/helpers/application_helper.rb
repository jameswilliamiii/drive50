module ApplicationHelper
  def user_timezone
    # Try to get timezone from session/cookie, fallback to browser detection via JavaScript
    # For now, we'll use the browser's timezone (detected via JavaScript)
    # In a production app, you might want to store this in the user's profile
    session[:timezone] || "UTC"
  end
end
