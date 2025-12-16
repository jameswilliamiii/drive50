require "test_helper"

class DriveSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get index" do
    get drive_sessions_url
    assert_response :success
  end

  test "should get new" do
    get new_drive_session_url
    assert_response :success
  end

  test "should create drive_session" do
    assert_difference("DriveSession.count") do
      post drive_sessions_url, params: {
        drive_session: {
          driver_name: "Test Driver",
          started_at: Time.current
        }
      }
    end

    assert_redirected_to drive_sessions_url
  end
end
