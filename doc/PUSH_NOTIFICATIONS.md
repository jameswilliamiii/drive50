# Web Push Notifications Setup

This app supports web push notifications that work across browsers and devices, including iOS when installed as a PWA.

## How It Works

The push notification system uses:

1. **Service Worker** - Handles incoming push events and displays notifications
2. **PushSubscription Model** - Stores user subscription data (endpoint, encryption keys)
3. **WebPushService** - Rails service for sending notifications to users
4. **Stimulus Controller** - Frontend UI for enabling/disabling notifications

## iOS Requirements

For push notifications to work on iOS devices:

1. The app **must be installed** to the home screen (Add to Home Screen in Safari)
2. The app **must be opened from the home screen icon** (standalone mode)
3. The manifest.json must have `"display": "standalone"` ✅ (already configured)
4. The user must grant notification permission when prompted

Push notifications will **NOT work** if the user:
- Opens the app in Safari browser directly
- Has not installed the app to their home screen

## User Setup

Users can enable notifications in the app:

1. Navigate to Settings (user edit page)
2. Click "Enable Notifications" in the Push Notifications section
3. Grant permission when prompted by the browser
4. On iOS: Make sure the app is installed to home screen first

## Sending Notifications

### From Code

Use the `WebPushService` to send notifications:

```ruby
# Notify a single user
WebPushService.notify_user(
  user,
  "Drive Complete!",
  "Great job! You completed a 30-minute drive session.",
  url: "/drive_sessions"
)

# Notify multiple users
users = User.where(id: [1, 2, 3])
WebPushService.notify_users(
  users,
  "New Feature!",
  "Check out the new analytics dashboard.",
  url: "/analytics"
)

# With custom options
WebPushService.notify_user(
  user,
  "Milestone Reached!",
  "You've completed 25 hours of practice driving!",
  url: "/drive_sessions",
  icon: "/icons/trophy.png",
  tag: "milestone-25",
  require_interaction: true
)
```

### From Rails Console

```ruby
# Find a user and send a test notification
user = User.find_by(email_address: "test@example.com")
WebPushService.notify_user(
  user,
  "Test Notification",
  "This is a test from Rails console!"
)
```

### Using Rake Task

```bash
# Send a test notification to a specific user
rails web_push:test_notification EMAIL='user@example.com'

# List all users with push subscriptions
rails web_push:list_subscriptions
```

## Example Use Cases

Here are some ideas for when you might want to send push notifications:

### 1. Drive Session Complete

```ruby
# In DriveSessionsController#complete
def complete
  @drive_session.update!(ended_at: Time.current)

  # Notify user about completed drive
  WebPushService.notify_user(
    Current.user,
    "Drive Session Complete!",
    "You drove for #{@drive_session.duration_minutes} minutes.",
    url: drive_sessions_path
  )
end
```

### 2. Milestone Achievements

```ruby
# After a drive session is saved
class DriveSession < ApplicationRecord
  after_save :check_milestones

  private

  def check_milestones
    total_hours = user.drive_sessions.sum(:duration_minutes) / 60.0

    if total_hours == 25 && total_hours_previously < 25
      WebPushService.notify_user(
        user,
        "Halfway There! 🎉",
        "You've completed 25 of 50 required hours!",
        url: "/drive_sessions"
      )
    end
  end
end
```

### 3. Reminder Notifications

```ruby
# Using a scheduled job (e.g., with Solid Queue)
class DriveReminderJob < ApplicationJob
  def perform
    # Find users who haven't driven in a week
    inactive_users = User.joins(:drive_sessions)
                         .where("drive_sessions.created_at < ?", 1.week.ago)
                         .distinct

    WebPushService.notify_users(
      inactive_users,
      "Time to Practice!",
      "It's been a while since your last drive session.",
      url: "/drive_sessions/new"
    )
  end
end
```

### 4. Goal Completion

```ruby
# When user reaches 50 hours
if user.total_hours >= 50 && user.night_hours >= 10
  WebPushService.notify_user(
    user,
    "Congratulations! 🎊",
    "You've completed all required driving hours!",
    url: "/drive_sessions",
    require_interaction: true
  )
end
```

## Testing Locally

1. Start your Rails server with HTTPS (required for service workers):
   ```bash
   bin/dev
   ```

2. Open the app in your browser (on desktop, use Chrome/Firefox/Edge)

3. Navigate to Settings and click "Enable Notifications"

4. Grant permission when prompted

5. Test sending a notification:
   ```bash
   rails web_push:test_notification EMAIL='your@email.com'
   ```

## Testing on iOS

1. Open the app in Safari on your iPhone/iPad
2. Tap the Share button → "Add to Home Screen"
3. Open the app from the home screen icon (not Safari)
4. Navigate to Settings → Enable Notifications
5. Grant permission when prompted
6. Send a test notification from Rails console/rake task
7. Lock your device or switch to another app
8. You should see the notification appear!

## VAPID Keys

VAPID (Voluntary Application Server Identification) keys are used to identify your server when sending push notifications.

Keys are stored in Rails credentials:
```yaml
vapid:
  public_key: "BEyYiKTjWIB8fJV1ZJkINm0e9CZRL8IlsUHo-UNJ9yfRoz4wIKBb6SfYw8zh1cLbAYs4a0sW8MIQVDFyHloPhoQ="
  private_key: "HMviFh_vtsklblg2BePpHRNRgKFrVFVLx0-YAWZVyv4="
```

To regenerate (don't do this unless necessary - it will invalidate all existing subscriptions):
```bash
rails runner "vapid_key = WebPush.generate_key; puts 'public_key: ' + vapid_key.public_key; puts 'private_key: ' + vapid_key.private_key"
```

## Troubleshooting

### Notifications not appearing on iOS
- Ensure app is installed to home screen
- Open app from home screen icon, not Safari
- Check notification permission in Settings
- Verify subscription exists in database

### Notifications not appearing on desktop
- Check browser notification permissions
- Ensure service worker is registered
- Check browser console for errors
- Verify VAPID keys are correct in credentials

### Subscription errors
If you see "Invalid Subscription" or "Expired Subscription" errors, the service will automatically remove the invalid subscription from the database.

## Resources

- [Web Push Notifications from Rails (Joy of Rails)](https://joyofrails.com/articles/web-push-notifications-from-rails)
- [Apple Developer: Sending web push notifications](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers)
- [web-push gem documentation](https://github.com/pushpad/web-push)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
