require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  # Disable fixtures since we create test data manually
  self.use_instantiated_fixtures = false

  def setup
    @user = User.create!(
      name: "Test User",
      email_address: "test@example.com",
      password: "password123"
    )
  end

  test "should create valid push subscription" do
    subscription = PushSubscription.new(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "test_p256dh_key",
      auth_key: "test_auth_key",
      user_agent: "Mozilla/5.0"
    )

    assert subscription.valid?
    assert subscription.save
  end

  test "should require endpoint" do
    subscription = PushSubscription.new(user: @user, p256dh_key: "key", auth_key: "auth")
    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "can't be blank"
  end

  test "should require valid URL for endpoint" do
    subscription = PushSubscription.new(
      user: @user,
      endpoint: "not-a-url",
      p256dh_key: "key",
      auth_key: "auth"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "must be a valid URL"
  end

  test "should require unique endpoint" do
    existing = PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/unique123",
      p256dh_key: "key1",
      auth_key: "auth1"
    )

    user2 = User.create!(
      name: "Test User 2",
      email_address: "test2@example.com",
      password: "password123"
    )

    duplicate = PushSubscription.new(
      user: user2,
      endpoint: existing.endpoint,
      p256dh_key: "key2",
      auth_key: "auth2"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:endpoint], "has already been taken"
  end

  test "should validate base64url format for keys" do
    subscription = PushSubscription.new(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "invalid key with spaces!",
      auth_key: "valid_key"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:p256dh_key], "must be valid base64url"
  end

  test "should limit user_agent length" do
    subscription = PushSubscription.new(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "key",
      auth_key: "auth",
      user_agent: "a" * 501
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:user_agent], "is too long (maximum is 500 characters)"
  end

  test "mark_as_active! should touch updated_at" do
    subscription = PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "key",
      auth_key: "auth",
      updated_at: 1.day.ago
    )

    old_time = subscription.updated_at
    subscription.mark_as_active!

    assert subscription.updated_at > old_time
  end
end
