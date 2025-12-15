class DriveSessionsController < ApplicationController
  before_action :set_drive_session, only: [ :edit, :update, :destroy, :complete ]

  def index
    @in_progress = DriveSession.in_progress.first
    @sessions = DriveSession.completed.ordered.limit(50)
    @total_hours = DriveSession.total_hours
    @night_hours = DriveSession.night_hours
    @hours_needed = DriveSession.hours_needed
    @night_hours_needed = DriveSession.night_hours_needed
  end

  def new
    @drive_session = DriveSession.new(
      started_at: Time.current,
      driver_name: params[:driver_name]
    )
  end

  def create
    @drive_session = DriveSession.new(drive_session_params)

    if @drive_session.save
      redirect_to drive_sessions_path, notice: "Drive started!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @drive_session.update(drive_session_params)
      redirect_to drive_sessions_path, notice: "Drive updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def complete
    @drive_session.update(ended_at: Time.current)
    redirect_to drive_sessions_path, notice: "Drive completed!"
  end

  def destroy
    @drive_session.destroy
    redirect_to drive_sessions_path, notice: "Drive deleted."
  end

  def export
    @sessions = DriveSession.completed.ordered

    respond_to do |format|
      format.csv do
        headers["Content-Disposition"] = "attachment; filename=\"driving-log-#{Date.current}.csv\""
        headers["Content-Type"] = "text/csv"
      end
    end
  end

  private

  def set_drive_session
    @drive_session = DriveSession.find(params[:id])
  end

  def drive_session_params
    params.require(:drive_session).permit(
      :driver_name,
      :supervisor_name,
      :started_at,
      :ended_at,
      :notes
    )
  end
end
