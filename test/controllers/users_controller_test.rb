require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get edit" do
    get edit_user_url
    assert_response :success
  end

  test "should update user" do
    patch user_url, params: { user: { name: "Updated Name", email_address: @user.email_address } }
    assert_redirected_to root_url
    @user.reload
    assert_equal "Updated Name", @user.name
  end
end
