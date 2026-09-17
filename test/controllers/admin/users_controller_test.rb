require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other = users(:two)
  end

  test "guest is redirected to sign in" do
    get admin_root_url
    assert_redirected_to new_session_url
  end

  test "non-admin is redirected to root with alert" do
    sign_in_as @user
    get admin_root_url
    assert_redirected_to root_url
    assert_equal "You are not authorized to access that page.", flash[:alert]
  end

  test "admin can view users index" do
    @user.update!(admin: true)
    sign_in_as @user
    get admin_users_url
    assert_response :success
  end

  test "admin can view other resource indexes" do
    @user.update!(admin: true)
    sign_in_as @user

    get admin_drive_sessions_url
    assert_response :success

    get admin_sessions_url
    assert_response :success

    get admin_push_subscriptions_url
    assert_response :success
  end

  test "admin datetimes render in Central Time with a zone abbreviation" do
    @user.update!(admin: true)
    sign_in_as @user

    drive = drive_sessions(:one)
    expected = I18n.localize(
      drive.started_at.in_time_zone(User::DEFAULT_TIMEZONE),
      format: :default
    )

    get admin_drive_session_url(drive)
    assert_response :success
    assert_includes response.body, expected
    assert_match(/\bC[DS]T\b/, expected)
  end

  test "admin can create a user with a password" do
    @user.update!(admin: true)
    sign_in_as @user

    assert_difference("User.count", 1) do
      post admin_users_url, params: {
        user: {
          first_name: "New",
          last_name: "Driver",
          email_address: "new.driver@example.com",
          password: "password123",
          password_confirmation: "password123",
          admin: false,
          hours_goal: 50,
          night_hours_goal: 10
        }
      }
    end

    created = User.find_by!(email_address: "new.driver@example.com")
    assert created.authenticate("password123")
    assert_equal false, created.admin?
  end

  test "admin can promote another user" do
    @user.update!(admin: true)
    sign_in_as @user

    patch admin_user_url(@other), params: {
      user: {
        first_name: @other.first_name,
        last_name: @other.last_name,
        email_address: @other.email_address,
        admin: true,
        hours_goal: @other.hours_goal,
        night_hours_goal: @other.night_hours_goal
      }
    }

    assert_redirected_to admin_user_url(@other)
    assert @other.reload.admin?
  end

  test "blank password on update leaves the existing password unchanged" do
    @user.update!(admin: true)
    sign_in_as @user
    digest_before = @other.password_digest

    patch admin_user_url(@other), params: {
      user: {
        first_name: "Renamed",
        last_name: @other.last_name,
        email_address: @other.email_address,
        password: "",
        password_confirmation: "",
        admin: false,
        hours_goal: @other.hours_goal,
        night_hours_goal: @other.night_hours_goal
      }
    }

    assert_redirected_to admin_user_url(@other)
    @other.reload
    assert_equal "Renamed", @other.first_name
    assert_equal digest_before, @other.password_digest
    assert @other.authenticate("password")
  end

  test "admin sees Admin link in the header menu" do
    @user.update!(admin: true)
    sign_in_as @user
    get root_url
    assert_select "a[href=?]", admin_root_path, text: "Admin"
  end

  test "non-admin does not see Admin link" do
    sign_in_as @user
    get root_url
    assert_select "a[href=?]", admin_root_path, text: "Admin", count: 0
  end
end
