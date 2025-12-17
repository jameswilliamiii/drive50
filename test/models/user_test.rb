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

  test "requires name" do
    user = User.new(email_address: "test@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "requires email_address" do
    user = User.new(name: "Test", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "requires unique email_address" do
    duplicate = User.new(
      name: "Another User",
      email_address: @user.email_address,
      password: "password"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  test "requires password" do
    user = User.new(name: "Test", email_address: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
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
