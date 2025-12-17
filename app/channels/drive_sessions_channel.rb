module ApplicationCable
  class DriveSessionsChannel < ActionCable::Channel::Base
    def subscribed
      stream_for current_user
    end
  end
end
