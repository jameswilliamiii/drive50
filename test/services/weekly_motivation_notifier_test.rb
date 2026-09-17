require "test_helper"

class WeeklyMotivationNotifierTest < ActiveSupport::TestCase
  setup do
    travel_to ActiveSupport::TimeZone[User::DEFAULT_TIMEZONE].local(2026, 9, 14, 9)
  end

  teardown do
    travel_back
  end

  test "builds general copy when the user drove last week" do
    user = eligible_user(hours_goal: 10, night_hours_goal: 0)
    completed_drive(user, started_at: last_week_noon, duration_hours: 2)

    assert_equal(
      {
        title: "Keep it up",
        body: "You drove 2 hours last week. 8 hours to go — a little this week keeps you on track."
      },
      WeeklyMotivationNotifier.message_for(user)
    )
  end

  test "builds quiet-week copy when the user did not drive last week" do
    user = eligible_user(hours_goal: 10, night_hours_goal: 0)
    completed_drive(user, started_at: Time.current - 6.hours, duration_hours: 2)

    assert_equal(
      {
        title: "Ready for a drive?",
        body: "8 hours left toward your goal. Even a short session this week helps."
      },
      WeeklyMotivationNotifier.message_for(user)
    )
  end

  test "builds almost-done total copy before quiet-week copy" do
    user = eligible_user(hours_goal: 10, night_hours_goal: 0)
    completed_drive(user, started_at: Time.current - 6.hours, duration_hours: 6)

    assert_equal(
      {
        title: "Almost there",
        body: "Only 4 hours left. You're so close — log a drive this week."
      },
      WeeklyMotivationNotifier.message_for(user)
    )
  end

  test "builds night nudge after the total-hours goal is met" do
    user = eligible_user(hours_goal: 10, night_hours_goal: 10)
    completed_drive(user, started_at: Time.current - 2.days, duration_hours: 10, night_hours: 2)

    assert_equal(
      {
        title: "Night hours needed",
        body: "You've hit your total hours — 8 hours of night driving left."
      },
      WeeklyMotivationNotifier.message_for(user)
    )
  end

  test "builds night almost-done copy" do
    user = eligible_user(hours_goal: 10, night_hours_goal: 10)
    completed_drive(user, started_at: Time.current - 2.days, duration_hours: 10, night_hours: 6)

    assert_equal(
      {
        title: "Finish strong",
        body: "Just 4 hours of night driving left. You're nearly done."
      },
      WeeklyMotivationNotifier.message_for(user)
    )
  end

  test "skips a user who met both goals" do
    user = eligible_user(hours_goal: 10, night_hours_goal: 10)
    completed_drive(user, started_at: Time.current - 2.days, duration_hours: 10, night_hours: 10)

    assert_nil WeeklyMotivationNotifier.message_for(user)
  end

  test "skips a user with weekly motivation disabled" do
    user = eligible_user(weekly_motivation_enabled: false)
    completed_drive(user, started_at: Time.current - 2.days, duration_hours: 1)

    assert_nil WeeklyMotivationNotifier.message_for(user)
  end

  test "skips a user without a push subscription" do
    user = eligible_user(push_subscription: false)
    completed_drive(user, started_at: Time.current - 2.days, duration_hours: 1)

    assert_nil WeeklyMotivationNotifier.message_for(user)
  end

  test "skips a user inactive for more than five weeks" do
    user = eligible_user
    completed_drive(user, started_at: Time.current - 6.weeks, duration_hours: 1)

    assert_nil WeeklyMotivationNotifier.message_for(user)
  end

  test "skips a user already sent a message today in Central time" do
    user = eligible_user(weekly_motivation_sent_on: Date.new(2026, 9, 14))
    completed_drive(user, started_at: Time.current - 2.days, duration_hours: 1)

    assert_nil WeeklyMotivationNotifier.message_for(user)
  end

  test "candidates prefilters subscription preference and recent activity" do
    eligible = eligible_user
    completed_drive(eligible, started_at: Time.current - 2.days, duration_hours: 1)

    disabled = eligible_user(weekly_motivation_enabled: false)
    completed_drive(disabled, started_at: Time.current - 2.days, duration_hours: 1)

    unsubscribed = eligible_user(push_subscription: false)
    completed_drive(unsubscribed, started_at: Time.current - 2.days, duration_hours: 1)

    inactive = eligible_user
    completed_drive(inactive, started_at: Time.current - 6.weeks, duration_hours: 1)

    already_sent = eligible_user(weekly_motivation_sent_on: Date.new(2026, 9, 14))
    completed_drive(already_sent, started_at: Time.current - 2.days, duration_hours: 1)

    assert_includes WeeklyMotivationNotifier.candidates, eligible
    refute_includes WeeklyMotivationNotifier.candidates, disabled
    refute_includes WeeklyMotivationNotifier.candidates, unsubscribed
    refute_includes WeeklyMotivationNotifier.candidates, inactive
    refute_includes WeeklyMotivationNotifier.candidates, already_sent
  end

  private

  def eligible_user(push_subscription: true, **attributes)
    user = User.create!(
      first_name: "Weekly",
      last_name: "Driver",
      email_address: "weekly-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      timezone: User::DEFAULT_TIMEZONE,
      **attributes
    )

    if push_subscription
      user.push_subscriptions.create!(
        endpoint: "https://example.com/push/#{SecureRandom.hex(6)}",
        p256dh_key: "test_key",
        auth_key: "test_auth"
      )
    end

    user
  end

  def completed_drive(user, started_at:, duration_hours:, night_hours: 0)
    drive = user.drive_sessions.create!(
      started_at: started_at,
      ended_at: started_at + duration_hours.hours
    )
    drive.update_columns(
      duration_minutes: duration_hours * 60,
      night_minutes: night_hours * 60
    )
    drive
  end

  def last_week_noon
    ActiveSupport::TimeZone[User::DEFAULT_TIMEZONE].local(2026, 9, 9, 12)
  end
end
