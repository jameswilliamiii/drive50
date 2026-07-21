require "test_helper"

class RootRoutingTest < ActionDispatch::IntegrationTest
  test "unauthenticated visitors get the marketing landing page at root" do
    get "/"

    assert_response :success
    assert_select "section.landing-hero"
    # The authenticated dashboard must not render for anonymous visitors.
    assert_select "#progress-summary", false
  end

  test "authenticated visitors get their dashboard at root" do
    sign_in_as users(:one)

    get "/"

    assert_response :success
    assert_select "#progress-summary"
    assert_select "section.landing-hero", false
  end
end
