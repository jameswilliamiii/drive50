require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "sign in offers a one-shot push prompt flag" do
    post session_url, params: { email_address: users(:one).email_address, password: "password" }
    assert_redirected_to root_url
    follow_redirect!
    assert_select "[data-offer-push-prompt=true]"
    assert_select ".push-prompt[data-controller=push-prompt]"
    assert_select ".push-prompt", text: /Enable drive reminders/
    assert_select ".push-prompt [data-action*=enable]", text: /Enable notifications/
    assert_select ".push-prompt [data-action*=dismiss]", text: /Not now/
    get root_url
    assert_select "[data-offer-push-prompt=true]", count: 0
  end
end
