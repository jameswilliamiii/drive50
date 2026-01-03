class DriveSessionsController < ApplicationController
  before_action :set_drive_session, only: [ :edit, :update, :destroy, :complete ]

  def index
    user_sessions = Current.user.drive_sessions
    @recent_sessions = user_sessions.completed.ordered.limit(3)

    stats = DriveSession.statistics_for(Current.user)
    @in_progress = stats[:in_progress]
    @total_hours = stats[:total_hours]
    @night_hours = stats[:night_hours]
    @hours_needed = stats[:hours_needed]
    @night_hours_needed = stats[:night_hours_needed]

    @activity_data = user_sessions.activity_by_date(days: DriveSession::ACTIVITY_CALENDAR_DAYS, timezone: Current.user.timezone)
  end

  def all
    user_sessions = Current.user.drive_sessions
    @pagy, @sessions = pagy(:offset, user_sessions.completed.ordered, limit: 20)

    stats = DriveSession.statistics_for(Current.user)
    @total_hours = stats[:total_hours]
    @night_hours = stats[:night_hours]
    @hours_needed = stats[:hours_needed]
    @night_hours_needed = stats[:night_hours_needed]

    if turbo_frame_request?
      render partial: "pagination_frame", formats: :turbo_stream and return
    end
  end

  def new
    existing_active = Current.user.drive_sessions.in_progress.first
    if existing_active
      redirect_to drive_sessions_path, alert: "You already have an active drive. Please complete it before starting a new one."
      return
    end

    @drive_session = Current.user.drive_sessions.build(
      started_at: Time.current
    )
  end

  def create
    existing_active = Current.user.drive_sessions.in_progress.first
    if existing_active
      redirect_to drive_sessions_path, alert: "You already have an active drive. Please complete it before starting a new one."
      return
    end

    @drive_session = Current.user.drive_sessions.build(
      started_at: params[:drive_session]&.dig(:started_at) || Time.current,
      driver_name: Current.user.name
    )

    if params[:drive_session].present?
      @drive_session.assign_attributes(drive_session_params)
    end

    if @drive_session.save
      redirect_to drive_sessions_path
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @drive_session.assign_attributes(drive_session_params)
    @drive_session.driver_name = Current.user.name

    if @drive_session.save
      redirect_to drive_sessions_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def complete
    @drive_session.update(ended_at: Time.current)
    redirect_to drive_sessions_path
  end

  def destroy
    @drive_session.destroy

    @recent_sessions = DriveSession.where(user_id: Current.user.id)
                                   .completed
                                   .ordered
                                   .limit(3)
                                   .to_a

    respond_to do |format|
      format.html { redirect_to drive_sessions_path }
      format.turbo_stream
    end
  end

  def export
    @sessions = Current.user.drive_sessions.completed.ordered

    respond_to do |format|
      format.csv do
        headers["Content-Disposition"] = "attachment; filename=\"driving-log-#{Date.current}.csv\""
        headers["Content-Type"] = "text/csv"
      end
    end
  end

  private

  def set_drive_session
    @drive_session = Current.user.drive_sessions.find(params[:id])
  end

  def drive_session_params
    params.require(:drive_session).permit(
      :started_at,
      :ended_at,
      :notes
    )
  end
end
