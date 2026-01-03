require "test_helper"

class DriveSessionReminderJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "sends push notification for in-progress drive session" do
    drive_session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
      started_at: Time.current
    )

    # Create a push subscription so WebPushJob has something to send to
    @user.push_subscriptions.create!(
      endpoint: "https://example.com/push",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    # Mock the WebPush call to avoid actual HTTP requests
    WebPush.expects(:payload_send).returns(true)

    # Should execute without raising errors
    assert_nothing_raised do
      DriveSessionReminderJob.perform_now(drive_session.id)
    end
  end

  test "does not send notification if drive session has ended" do
    drive_session = @user.drive_sessions.create!(
      driver_name: "Test Driver",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )

    # Should not call WebPush at all
    WebPush.expects(:payload_send).never

    DriveSessionReminderJob.perform_now(drive_session.id)
  end

  test "does not send notification if drive session no longer exists" do
    # Should not call WebPush at all
    WebPush.expects(:payload_send).never

    DriveSessionReminderJob.perform_now(999999)
  end
end
