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

  test "should update user name" do
    patch user_url, params: { user: { first_name: "Updated", last_name: "Name", email_address: @user.email_address } }
    assert_redirected_to edit_user_url
    @user.reload
    assert_equal "Updated", @user.first_name
    assert_equal "Name", @user.last_name
  end

  test "should update user email" do
    patch user_url, params: { user: { first_name: @user.first_name, last_name: @user.last_name, email_address: "newemail@example.com" } }
    assert_redirected_to edit_user_url
    @user.reload
    assert_equal "newemail@example.com", @user.email_address
  end

  test "should update user password" do
    new_password = "newpassword123"
    patch user_url, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        email_address: @user.email_address,
        password: new_password,
        password_confirmation: new_password
      }
    }

    assert_redirected_to edit_user_url
    @user.reload
    assert @user.authenticate(new_password)
  end

  test "should not update user with invalid data" do
    patch user_url, params: { user: { first_name: "", last_name: "", email_address: "" } }
    assert_response :unprocessable_content
  end

  test "should not update user with mismatched passwords" do
    patch user_url, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        email_address: @user.email_address,
        password: "newpassword",
        password_confirmation: "different"
      }
    }
    assert_response :unprocessable_content
  end

  test "should not update to duplicate email" do
    other_user = users(:two)
    patch user_url, params: { user: { first_name: @user.first_name, last_name: @user.last_name, email_address: other_user.email_address } }
    assert_response :unprocessable_content
  end

  test "should require authentication" do
    delete session_url
    get edit_user_url
    assert_redirected_to new_session_url
  end

  test "should only update current user" do
    patch user_url, params: { user: { first_name: "Updated", last_name: "Name", email_address: @user.email_address } }
    @user.reload
    assert_equal "Updated", @user.first_name

    # Other users should not be affected
    other_user = users(:two)
    other_user.reload
    assert_not_equal "Updated", other_user.first_name
  end

  test "should update user location coordinates" do
    patch user_url, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        email_address: @user.email_address,
        latitude: 41.8781,
        longitude: -87.6298
      }
    }

    assert_redirected_to edit_user_url
    @user.reload
    assert_equal 41.8781, @user.latitude.to_f
    assert_equal(-87.6298, @user.longitude.to_f)
  end

  test "should clear user location coordinates" do
    @user.update!(latitude: 41.8781, longitude: -87.6298)

    patch user_url, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        email_address: @user.email_address,
        latitude: "",
        longitude: ""
      }
    }

    assert_redirected_to edit_user_url
    @user.reload
    assert_nil @user.latitude
    assert_nil @user.longitude
  end
end
