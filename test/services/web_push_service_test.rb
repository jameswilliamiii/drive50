require "test_helper"

class WebPushServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Disable fixtures since we create test data manually
  self.use_instantiated_fixtures = false

  def setup
    @user = User.create!(
      name: "Test User",
      email_address: "webpush@example.com",
      password: "password123"
    )
    @subscription = PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )
  end

  test "notify_user should enqueue WebPushJob" do
    assert_enqueued_with(job: WebPushJob) do
      WebPushService.notify_user(@user, "Test", "Body", url: "/test")
    end
  end

  test "notify_user should return false when user has no subscriptions" do
    user_without_subs = User.create!(
      name: "User Without Subs",
      email_address: "nosubs@example.com",
      password: "password123"
    )
    result = WebPushService.notify_user(user_without_subs, "Test", "Body")
    assert_equal false, result
  end

  test "notify_user should raise ArgumentError for blank title" do
    assert_raises(ArgumentError, match: /title cannot be blank/) do
      WebPushService.notify_user(@user, "", "Body")
    end
  end

  test "notify_user should raise ArgumentError for blank body" do
    assert_raises(ArgumentError, match: /body cannot be blank/) do
      WebPushService.notify_user(@user, "Title", "")
    end
  end

  test "notify_users should enqueue WebPushJob with multiple user_ids" do
    user2 = User.create!(
      name: "User Two",
      email_address: "user2@example.com",
      password: "password123"
    )
    PushSubscription.create!(
      user: user2,
      endpoint: "https://fcm.googleapis.com/fcm/send/test2",
      p256dh_key: "key2",
      auth_key: "auth2"
    )

    assert_enqueued_with(job: WebPushJob, args: [ { user_ids: [ @user.id, user2.id ], title: "Test", body: "Body", url: nil, options: {} } ]) do
      WebPushService.notify_users([ @user, user2 ], "Test", "Body")
    end
  end

  test "notify_users should return false for empty array" do
    result = WebPushService.notify_users([], "Test", "Body")
    assert_equal false, result
  end

  test "validate_configuration! should raise when keys missing" do
    Rails.application.credentials.stubs(:dig).with(:vapid, :public_key).returns(nil)
    Rails.application.credentials.stubs(:dig).with(:vapid, :private_key).returns(nil)

    assert_raises(WebPushService::ConfigurationError, match: /VAPID keys not configured/) do
      WebPushService.validate_configuration!
    end
  end

  test "validate_configuration! should not raise when keys present" do
    # Assuming credentials are properly set in test environment
    assert_nothing_raised do
      WebPushService.validate_configuration!
    end
  end
end
