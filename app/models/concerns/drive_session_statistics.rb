module DriveSessionStatistics
  extend ActiveSupport::Concern

  included do
    # Make these methods available on the DriveSession class
  end

  class_methods do
    # Calculate all statistics for a user's drive sessions
    def statistics_for(user_or_relation)
      relation = user_or_relation.is_a?(ActiveRecord::Relation) ? user_or_relation : user_or_relation.drive_sessions

      {
        total_hours: relation.completed.sum(:duration_minutes) / 60.0,
        night_hours: relation.night_drives.completed.sum(:duration_minutes) / 60.0,
        hours_needed: [ DriveSession::HOURS_NEEDED - (relation.completed.sum(:duration_minutes) / 60.0), 0 ].max,
        night_hours_needed: [ DriveSession::NIGHT_HOURS_NEEDED - (relation.night_drives.completed.sum(:duration_minutes) / 60.0), 0 ].max,
        in_progress: relation.in_progress.first
      }
    end
  end
end
