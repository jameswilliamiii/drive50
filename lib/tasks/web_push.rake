namespace :web_push do
  desc "Send a test push notification to a user (usage: rails web_push:test_notification EMAIL='user@example.com')"
  task test_notification: :environment do
    email = ENV["EMAIL"]

    unless email
      puts "Usage: rails web_push:test_notification EMAIL='user@example.com'"
      exit 1
    end

    user = User.find_by(email_address: email)

    unless user
      puts "User not found with email: #{email}"
      exit 1
    end

    unless user.push_subscriptions.any?
      puts "User #{email} has no push subscriptions"
      puts "They need to enable notifications in the app settings first"
      exit 1
    end

    WebPushService.notify_user(
      user,
      "Test Notification",
      "This is a test push notification from Drive50!",
      url: "/drive_sessions"
    )

    puts "Test notification sent to #{user.name} (#{email})"
    puts "Active subscriptions: #{user.push_subscriptions.count}"
  end

  desc "List all users with push subscriptions"
  task list_subscriptions: :environment do
    users_with_subscriptions = User.joins(:push_subscriptions).distinct

    if users_with_subscriptions.empty?
      puts "No users have push subscriptions enabled"
      exit
    end

    puts "Users with push notifications enabled:"
    puts "-" * 60

    users_with_subscriptions.each do |user|
      subscription_count = user.push_subscriptions.count
      puts "#{user.name} (#{user.email_address}): #{subscription_count} subscription(s)"
    end
  end
end
