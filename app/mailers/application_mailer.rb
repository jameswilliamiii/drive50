class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.dig(:mail, :from) || "noreply@drive50.app"
  layout "mailer"
end
