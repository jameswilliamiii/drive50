module PushNotificationsHelper
  # The one place push-reminder wording lives. Onboarding, the post-sign-in
  # prompt, and Settings all render from here so title/why/install copy cannot
  # drift — they already had three copies of the iOS note alone.
  PUSH_REMINDERS_TITLE = "Enable drive reminders"
  PUSH_REMINDERS_WHY =
    "If a drive timer is still running, Drive50 can nudge you so hours are not left open by mistake."
  PUSH_IOS_INSTALL_NOTE =
    "Push notifications only work when this app is installed to your home screen and opened from there (standalone mode)."

  def push_reminders_title
    PUSH_REMINDERS_TITLE
  end

  def push_reminders_why
    PUSH_REMINDERS_WHY
  end

  def push_ios_install_note
    PUSH_IOS_INSTALL_NOTE
  end
end
