class DriveSessionReminderJob < ApplicationJob
  queue_as :default

  # Retry on transient errors, but not on permanent failures like deleted records
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(drive_session_id)
    drive_session = DriveSession.find_by(id: drive_session_id)

    # Don't send notification if drive session no longer exists or has ended
    return unless drive_session&.in_progress?

    # Send push notification to the user
    WebPushJob.perform_now(
      user_ids: [ drive_session.user_id ],
      title: "Drive in Progress",
      body: "You've been driving for over #{DriveSession::REMINDER_DELAY.in_minutes.to_i} minutes. Don't forget to end your session!",
      url: "/",
      options: {
        tag: "drive-reminder-#{drive_session.id}",
        require_interaction: true
      }
    )
  end
end
