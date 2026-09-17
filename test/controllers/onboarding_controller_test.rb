require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  test "location requires authentication" do
    get onboarding_location_url
    assert_redirected_to new_session_url
  end

  test "location without onboarding session redirects to dashboard" do
    sign_in_as users(:one)
    get onboarding_location_url
    assert_redirected_to root_url
  end

  test "location with onboarding session renders" do
    register_and_start_onboarding!
    follow_redirect!
    assert_response :success
    assert_select "body.onboarding-focused"
    assert_select ".bottom-nav", count: 0
    assert_select "#fab-new-drive-wrapper", count: 0
    assert_select ".header-nav", count: 0
  end

  test "fetching the VAPID key does not clear onboarding" do
    Rails.application.credentials.stubs(:dig).with(:vapid, :public_key).returns("test_public_key")
    register_and_start_onboarding!
    get new_push_subscription_url, as: :json
    assert_response :success
    get onboarding_push_url
    assert_response :success
  end

  test "timezone update does not clear onboarding" do
    register_and_start_onboarding!
    post timezone_url, params: { timezone: "America/Chicago" }, as: :json
    get onboarding_location_url
    assert_response :success
  end

  test "opening the dashboard clears onboarding" do
    register_and_start_onboarding!
    get root_url
    get onboarding_location_url
    assert_redirected_to root_url
  end

  test "finish clears onboarding and welcomes the user" do
    register_and_start_onboarding!
    post onboarding_finish_url
    assert_redirected_to root_url
    refute session[:show_onboarding]
    assert_equal "Welcome! Your account has been created.", flash[:notice]
    get onboarding_location_url
    assert_redirected_to root_url
  end

  test "onboarding finish does not offer the push prompt" do
    register_and_start_onboarding!
    post onboarding_finish_url
    follow_redirect!
    assert_select "[data-offer-push-prompt=true]", count: 0
  end

  test "save_location stores coordinates and continues to push" do
    user = register_and_start_onboarding!
    post onboarding_location_url, params: { user: { latitude: 41.88, longitude: -87.63 } }
    assert_redirected_to onboarding_push_url
    assert_in_delta 41.88, user.reload.latitude, 0.01
  end

  test "skip location continues to push without coordinates" do
    user = register_and_start_onboarding!
    get onboarding_push_url
    assert_response :success
    assert_nil user.reload.latitude
  end

  test "push step renders during onboarding" do
    register_and_start_onboarding!
    get onboarding_push_url
    assert_response :success
    assert_match(/reminder/i, response.body)
    assert_select "body.onboarding-focused"
    assert_select ".bottom-nav", count: 0
    assert_select ".header-nav", count: 0
  end
end
