require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "new returns VAPID public key when configured" do
    get new_push_subscription_url, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["public_key"].present?
  end

  test "create with valid subscription data" do
    subscription_data = {
      subscription: {
        endpoint: "https://fcm.googleapis.com/fcm/send/test123",
        keys: {
          p256dh: "test_p256dh_key",
          auth: "test_auth_key"
        }
      }
    }

    assert_difference "PushSubscription.count", 1 do
      post push_subscription_url, params: subscription_data, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
  end

  test "create with invalid endpoint" do
    subscription_data = {
      subscription: {
        endpoint: "not-a-url",
        keys: {
          p256dh: "test_key",
          auth: "test_auth"
        }
      }
    }

    assert_no_difference "PushSubscription.count" do
      post push_subscription_url, params: subscription_data, as: :json
    end

    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_equal "Invalid endpoint URL", json["error"]
  end

  test "create updates existing subscription" do
    existing = PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/existing",
      p256dh_key: "old_key",
      auth_key: "old_auth"
    )

    subscription_data = {
      subscription: {
        endpoint: existing.endpoint,
        keys: {
          p256dh: "new_key",
          auth: "new_auth"
        }
      }
    }

    assert_no_difference "PushSubscription.count" do
      post push_subscription_url, params: subscription_data, as: :json
    end

    assert_response :created
    existing.reload
    assert_equal "new_key", existing.p256dh_key
    assert_equal "new_auth", existing.auth_key
  end

  test "destroy removes subscription" do
    subscription = PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test456",
      p256dh_key: "key",
      auth_key: "auth"
    )

    assert_difference "PushSubscription.count", -1 do
      delete push_subscription_url, params: { endpoint: subscription.endpoint }, as: :json
    end

    assert_response :no_content
  end

  test "destroy with invalid endpoint" do
    delete push_subscription_url, params: { endpoint: "not-a-url" }, as: :json

    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_equal "Invalid endpoint URL", json["error"]
  end

  test "destroy with non-existent subscription" do
    endpoint = "https://fcm.googleapis.com/fcm/send/nonexistent"
    delete push_subscription_url, params: { endpoint: endpoint }, as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Subscription not found", json["error"]
  end

  test "requires authentication for all actions" do
    sign_out

    get new_push_subscription_url, as: :json
    assert_response :redirect

    post push_subscription_url, params: { subscription: { endpoint: "test" } }, as: :json
    assert_response :redirect

    delete push_subscription_url, params: { endpoint: "https://example.com" }, as: :json
    assert_response :redirect
  end
end
