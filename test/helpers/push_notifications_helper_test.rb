require "test_helper"

class PushNotificationsHelperTest < ActionView::TestCase
  test "reminder title and why are shared across surfaces" do
    assert_equal "Enable drive reminders", push_reminders_title
    assert_match(/drive timer is still running/, push_reminders_why)
  end

  test "ios install note is a single shared string" do
    assert_match(/home screen/, push_ios_install_note)
    assert_match(/standalone/, push_ios_install_note)
  end
end
