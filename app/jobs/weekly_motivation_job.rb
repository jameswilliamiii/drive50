class WeeklyMotivationJob < ApplicationJob
  queue_as :default

  def perform
    today = Time.current.in_time_zone(User::DEFAULT_TIMEZONE).to_date
    sent_count = 0
    skipped_count = 0
    failure_count = 0

    WeeklyMotivationNotifier.candidates.find_each do |user|
      message = WeeklyMotivationNotifier.message_for(user)
      next unless message

      begin
        sent = WebPushService.notify_user(
          user,
          message[:title],
          message[:body],
          url: "/",
          tag: "weekly-motivation"
        )
        if sent
          user.update!(weekly_motivation_sent_on: today)
          sent_count += 1
        else
          skipped_count += 1
        end
      rescue StandardError => error
        failure_count += 1
        Rails.logger.error(
          "WeeklyMotivationJob failed for user #{user.id}: #{error.class}: #{error.message}"
        )
      end
    end

    Rails.logger.info(
      "WeeklyMotivationJob completed: #{sent_count} sent, #{skipped_count} skipped, #{failure_count} failed"
    )
  end
end
