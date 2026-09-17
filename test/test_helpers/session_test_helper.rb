module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end

  def register_and_start_onboarding!(email: "newbie-#{SecureRandom.hex(4)}@example.com")
    post registrations_url, params: {
      user: {
        first_name: "New",
        last_name: "Driver",
        email_address: email,
        password: "password123",
        password_confirmation: "password123"
      }
    }
    assert_redirected_to onboarding_location_url
    assert session[:show_onboarding]
    User.find_by!(email_address: email)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
