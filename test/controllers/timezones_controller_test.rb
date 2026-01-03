require "test_helper"

class TimezonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should update timezone in session when not authenticated" do
    post timezone_path, params: { timezone: "America/New_York" }, as: :json

    assert_response :success
    assert_equal "America/New_York", session[:timezone]
  end

  test "should update timezone for authenticated user" do
    sign_in_as @user

    # User has default timezone of UTC from migration
    assert_equal "UTC", @user.timezone

    post timezone_path, params: { timezone: "America/Los_Angeles" }, as: :json

    assert_response :success
    assert_equal "America/Los_Angeles", session[:timezone]
    assert_equal "America/Los_Angeles", @user.reload.timezone
  end

  test "should not update user timezone if already set to same value" do
    @user.update_column(:timezone, "America/Chicago")
    sign_in_as @user

    post timezone_path, params: { timezone: "America/Chicago" }, as: :json

    assert_response :success
    assert_equal "America/Chicago", @user.reload.timezone
  end

  test "should return unprocessable_entity if timezone is blank" do
    post timezone_path, params: { timezone: "" }, as: :json

    assert_response :unprocessable_entity
  end

  test "should return unprocessable_entity if timezone is missing" do
    post timezone_path, as: :json

    assert_response :unprocessable_entity
  end
end
