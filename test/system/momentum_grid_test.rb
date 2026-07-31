require "application_system_test_case"

# Deliberately minimal. Driving the modals from a browser proved not to be worth
# it: a click that lands before Stimulus has connected the <body> controllers does
# nothing, and Capybara will not retry it because the click itself succeeded. The
# result was an intermittently red suite that told us less than the tests below it.
#
# What the modals render is asserted where it is fast and deterministic:
# test/models/activity_day_test.rb (payload, totals, state, aria label) and
# test/controllers/drive_sessions_controller_test.rb (cell markup, the
# data-day-summary attribute, future-cell inertness).
#
# That leaves one thing a browser is genuinely needed for, and it clicks nothing,
# so it has no timing race.
class MomentumGridTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(timezone: ApplicationSystemTestCase::BROWSER_TIME_ZONE)
  end

  # The modal controllers sit on <body>, which renders on every page — including
  # signed-out ones, where the dialog partials do not render at all. A controller
  # reaching for a target that only exists when signed in threw here.
  test "the pages the modal controllers mount on load without JavaScript errors" do
    sign_in
    [ drive_sessions_path, all_drive_sessions_path ].each do |path|
      visit path
      assert_empty severe_console_messages, "#{path} logged a JS error"
    end

    # Signed out is the case that regressed, so assert the dialogs really are
    # absent — otherwise this only exercises pages that happen to render them.
    page.driver.browser.manage.delete_all_cookies
    visit new_session_path
    assert_selector "body[data-controller~='day-modal']"
    assert_no_selector "dialog", visible: :all
    assert_empty severe_console_messages, "the signed-out page logged a JS error"
  end

  private

  def severe_console_messages
    page.driver.browser.logs.get(:browser).select { |entry| entry.level == "SEVERE" }.map(&:message)
  end

  def sign_in
    visit new_session_path
    fill_in "Email Address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign In"
    assert_selector ".activity-cal"
  end
end
