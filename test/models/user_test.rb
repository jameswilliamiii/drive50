require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # Validations
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires first_name" do
    user = User.new(email_address: "test@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    user = User.new(email_address: "test@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "full_name joins first and last name" do
    user = User.new(first_name: "Sarah", last_name: "Mitchell")
    assert_equal "Sarah Mitchell", user.full_name
  end

  test "full_name omits a missing last name without trailing space" do
    user = User.new(first_name: "Cher", last_name: nil)
    assert_equal "Cher", user.full_name
  end

  test "requires email_address" do
    user = User.new(first_name: "Test", last_name: "User", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "requires unique email_address" do
    duplicate = User.new(
      first_name: "Another",
      last_name: "User",
      email_address: @user.email_address,
      password: "password"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  test "requires password" do
    user = User.new(first_name: "Test", last_name: "User", email_address: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "defaults hours_goal and night_hours_goal to 50/10" do
    user = User.new
    assert_equal 50, user.hours_goal
    assert_equal 10, user.night_hours_goal
  end

  test "defaults timezone to the app's default zone" do
    assert_equal User::DEFAULT_TIMEZONE, User.new.timezone
  end

  test "rejects a zero or negative hours_goal" do
    user = User.new(hours_goal: 0)
    assert_not user.valid?
    assert_includes user.errors[:hours_goal], "must be greater than 0"
  end

  test "rejects an hours_goal over the upper bound" do
    user = User.new(hours_goal: User::MAX_HOURS_GOAL + 1)
    assert_not user.valid?
    assert_includes user.errors[:hours_goal], "must be less than or equal to #{User::MAX_HOURS_GOAL}"
  end

  test "rejects a non-integer hours_goal" do
    user = User.new(hours_goal: 40.5)
    assert_not user.valid?
    assert_includes user.errors[:hours_goal], "must be an integer"
  end

  test "rejects a negative night_hours_goal" do
    user = User.new(night_hours_goal: -1)
    assert_not user.valid?
    assert_includes user.errors[:night_hours_goal], "must be greater than or equal to 0"
  end

  test "allows a night_hours_goal of 0" do
    user = User.new(first_name: "T", last_name: "U", email_address: "zero-night@example.com",
                     password: "password123", hours_goal: 40, night_hours_goal: 0)
    assert user.valid?
  end

  test "rejects a night_hours_goal greater than hours_goal" do
    user = User.new(hours_goal: 20, night_hours_goal: 21)
    assert_not user.valid?
    assert_includes user.errors[:night_hours_goal], "can't be more than the total hours goal"
  end

  test "allows night_hours_goal equal to hours_goal" do
    user = User.new(first_name: "T", last_name: "U", email_address: "equal-goal@example.com",
                     password: "password123", hours_goal: 10, night_hours_goal: 10)
    assert user.valid?
  end

  # Associations
  test "has many sessions" do
    assert_respond_to @user, :sessions
  end

  test "has many drive_sessions" do
    assert_respond_to @user, :drive_sessions
  end

  test "destroys dependent sessions" do
    @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test")
    assert_difference("Session.count", -1) do
      @user.destroy
    end
  end

  test "destroys dependent drive_sessions" do
    assert_difference("DriveSession.count", -@user.drive_sessions.count) do
      @user.destroy
    end
  end

  # Password reset
  test "generates password reset token" do
    token = @user.password_reset_token
    assert_not_nil token
    assert_kind_of String, token
  end

  test "finds user by valid password reset token" do
    token = @user.password_reset_token
    found_user = User.find_by_password_reset_token!(token)
    assert_equal @user, found_user
  end

  test "raises error for invalid password reset token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_password_reset_token!("invalid-token")
    end
  end

  test "password reset token expires after 1 hour" do
    token = @user.password_reset_token
    travel 61.minutes do
      assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
        User.find_by_password_reset_token!(token)
      end
    end
  end
end
