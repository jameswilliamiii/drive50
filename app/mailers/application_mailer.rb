class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.dig(:mail, :from) || "noreply@example.com"
  layout "mailer"
end
