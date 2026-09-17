require "test_helper"

class WeeklyMotivationJobTest < ActiveJob::TestCase
  setup do
    travel_to ActiveSupport::TimeZone[User::DEFAULT_TIMEZONE].local(2026, 9, 14, 9)
  end

  teardown do
    travel_back
  end

  test "sends an eligible user a weekly motivation push and records the send date" do
    user = eligible_user
    message = WeeklyMotivationNotifier.message_for(user)

    WebPushService.expects(:notify_user).with(
      user,
      message[:title],
      message[:body],
      url: "/",
      tag: "weekly-motivation"
    ).returns(true)

    WeeklyMotivationJob.perform_now

    assert_equal Date.new(2026, 9, 14), user.reload.weekly_motivation_sent_on
  end

  test "does not notify an ineligible user" do
    eligible_user(weekly_motivation_enabled: false)
    WebPushService.expects(:notify_user).never

    WeeklyMotivationJob.perform_now
  end

  test "continues processing users after one notification fails" do
    failing_user = eligible_user
    successful_user = eligible_user

    WebPushService.expects(:notify_user).with(
      failing_user,
      anything,
      anything,
      url: "/",
      tag: "weekly-motivation"
    ).raises(StandardError, "push failed")
    WebPushService.expects(:notify_user).with(
      successful_user,
      anything,
      anything,
      url: "/",
      tag: "weekly-motivation"
    ).returns(true)
    Rails.logger.expects(:error).with(
      "WeeklyMotivationJob failed for user #{failing_user.id}: StandardError: push failed"
    )

    WeeklyMotivationJob.perform_now

    assert_nil failing_user.reload.weekly_motivation_sent_on
    assert_equal Date.new(2026, 9, 14), successful_user.reload.weekly_motivation_sent_on
  end

  test "does not record the send date when no push was enqueued" do
    user = eligible_user
    WebPushService.stubs(:notify_user).returns(false)

    WeeklyMotivationJob.perform_now

    assert_nil user.reload.weekly_motivation_sent_on
  end

  private

  def eligible_user(**attributes)
    user = User.create!(
      first_name: "Weekly",
      last_name: "Driver",
      email_address: "weekly-job-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      timezone: User::DEFAULT_TIMEZONE,
      **attributes
    )
    user.push_subscriptions.create!(
      endpoint: "https://example.com/push/#{SecureRandom.hex(6)}",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )
    started_at = Time.current - 2.days
    user.drive_sessions.create!(
      started_at: started_at,
      ended_at: started_at + 1.hour
    )
    user
  end
end
