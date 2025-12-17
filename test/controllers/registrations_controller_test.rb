require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_url
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
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
          name: "",
          email_address: "invalid",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with mismatched passwords" do
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: "test@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with duplicate email" do
    existing_user = users(:one)
    assert_no_difference("User.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: existing_user.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should start session after successful registration" do
    assert_difference("Session.count") do
      post registrations_url, params: {
        user: {
          name: "Test User",
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
  end
end
