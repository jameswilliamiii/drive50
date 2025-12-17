require "test_helper"

class DriveSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @drive_session = drive_sessions(:one)
  end

  test "should get index" do
    get drive_sessions_url
    assert_response :success
  end

  test "should get all" do
    get all_drive_sessions_url
    assert_response :success
  end

  test "should get new" do
    # Complete any in-progress sessions first
    @user.drive_sessions.in_progress.destroy_all
    get new_drive_session_url
    assert_response :success
  end

  test "should not get new when active drive exists" do
    @user.drive_sessions.create!(driver_name: "Test", started_at: Time.current)
    get new_drive_session_url
    assert_redirected_to drive_sessions_url
    assert_equal "You already have an active drive. Please complete it before starting a new one.", flash[:alert]
  end

  test "should create drive_session" do
    @user.drive_sessions.in_progress.destroy_all
    assert_difference("DriveSession.count") do
      post drive_sessions_url, params: {
        drive_session: {
          driver_name: "Test Driver",
          started_at: Time.current
        }
      }
    end

    assert_redirected_to drive_sessions_url
  end

  test "should not create drive_session when active drive exists" do
    @user.drive_sessions.create!(driver_name: "Test", started_at: Time.current)
    assert_no_difference("DriveSession.count") do
      post drive_sessions_url, params: {
        drive_session: {
          driver_name: "Test Driver",
          started_at: Time.current
        }
      }
    end

    assert_redirected_to drive_sessions_url
    assert_equal "You already have an active drive. Please complete it before starting a new one.", flash[:alert]
  end

  test "should get edit" do
    get edit_drive_session_url(@drive_session)
    assert_response :success
  end

  test "should update drive_session" do
    patch drive_session_url(@drive_session), params: {
      drive_session: {
        notes: "Updated notes"
      }
    }
    assert_redirected_to drive_sessions_url
    @drive_session.reload
    assert_equal "Updated notes", @drive_session.notes
  end

  test "should not update with invalid data" do
    patch drive_session_url(@drive_session), params: {
      drive_session: {
        started_at: Time.current,
        ended_at: 1.hour.ago
      }
    }
    assert_response :unprocessable_entity
  end

  test "should complete drive_session" do
    in_progress = @user.drive_sessions.create!(
      driver_name: "Test",
      started_at: 1.hour.ago
    )

    assert_nil in_progress.ended_at
    post complete_drive_session_url(in_progress)
    in_progress.reload
    assert_not_nil in_progress.ended_at
    assert_redirected_to drive_sessions_url
  end

  test "should destroy drive_session" do
    assert_difference("DriveSession.count", -1) do
      delete drive_session_url(@drive_session)
    end

    assert_redirected_to drive_sessions_url
  end

  test "should export drive sessions as CSV" do
    get export_drive_sessions_url(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.content_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "index displays statistics" do
    get drive_sessions_url
    assert_response :success
    assert_select "div", /hours/i
  end

  test "all uses pagination" do
    # Create enough sessions to trigger pagination
    20.times do |i|
      @user.drive_sessions.create!(
        driver_name: "Test #{i}",
        started_at: (i + 1).hours.ago,
        ended_at: i.hours.ago
      )
    end

    get all_drive_sessions_url
    assert_response :success
  end

  test "should require authentication" do
    delete session_url
    get drive_sessions_url
    assert_redirected_to new_session_url
  end

  test "should only show current user's drive sessions" do
    other_user = users(:two)
    other_session = other_user.drive_sessions.create!(
      driver_name: "Other User",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )

    get drive_sessions_url
    assert_response :success
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(other_session)}", count: 0
  end
end
