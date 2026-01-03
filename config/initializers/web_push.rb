# Validate VAPID configuration on application boot
Rails.application.config.after_initialize do
  if Rails.env.production?
    begin
      WebPushService.validate_configuration!
      Rails.logger.info "✓ VAPID keys configured successfully"
    rescue WebPushService::ConfigurationError => e
      Rails.logger.error "✗ #{e.message}"
      Rails.logger.error "Run: rails credentials:edit and add VAPID keys"
      Rails.logger.error "Generate keys with: rails runner \"vapid_key = WebPush.generate_key; puts 'public_key: ' + vapid_key.public_key; puts 'private_key: ' + vapid_key.private_key\""
    end
  end
end
