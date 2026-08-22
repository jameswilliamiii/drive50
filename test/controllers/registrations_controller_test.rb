require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_url
    assert_response :success
  end

  test "the timezone detector falls back to the default zone for a visitor with no session timezone" do
    get new_registration_url

    assert_select "body[data-timezone-detector-current-value=?]", User::DEFAULT_TIMEZONE
  end

  test "the timezone detector uses a visitor's already-detected session timezone" do
    post timezone_path, params: { timezone: "America/Denver" }, as: :json
    assert_response :success

    get new_registration_url

    assert_select "body[data-timezone-detector-current-value=?]", "America/Denver"
  end

  test "should create user" do
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          first_name: "Test",
          last_name: "User",
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_url
    assert cookies[:session_id], "Should create session cookie"
  end

  test "should not create user with invalid data" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          first_name: "",
          last_name: "",
          email_address: "invalid",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "should not create user with mismatched passwords" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          first_name: "Test",
          last_name: "User",
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "should not create user with duplicate email" do
    existing_user = users(:one)
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          first_name: "Test",
          last_name: "User",
          email_address: existing_user.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "should start session after successful registration" do
    assert_difference("Session.count") do
      post registrations_url, params: {
        user: {
          first_name: "Test",
          last_name: "User",
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
  end

  test "defaults to the app's 50/10 when hours goals are omitted" do
    post registrations_url, params: {
      user: {
        first_name: "Test",
        last_name: "User",
        email_address: "default-goals@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    user = User.find_by(email_address: "default-goals@example.com")
    assert_equal 50, user.hours_goal
    assert_equal 10, user.night_hours_goal
  end

  test "should create a user with a custom hours goal" do
    post registrations_url, params: {
      user: {
        first_name: "Test",
        last_name: "User",
        email_address: "custom-goals@example.com",
        password: "password123",
        password_confirmation: "password123",
        hours_goal: 40,
        night_hours_goal: 6
      }
    }

    user = User.find_by(email_address: "custom-goals@example.com")
    assert_equal 40, user.hours_goal
    assert_equal 6, user.night_hours_goal
  end

  test "should not create a user whose night hours goal exceeds the total" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          first_name: "Test",
          last_name: "User",
          email_address: "bad-goals@example.com",
          password: "password123",
          password_confirmation: "password123",
          hours_goal: 20,
          night_hours_goal: 21
        }
      }
    end

    assert_response :unprocessable_content
  end
end
