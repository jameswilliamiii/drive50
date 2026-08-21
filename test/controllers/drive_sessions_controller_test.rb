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

  test "the dashboard day and night tiles open the drive log filtered to match" do
    get drive_sessions_url

    assert_select "a.dash-hero-chip.is-day[href=?]", all_drive_sessions_path(kind: "day")
    assert_select "a.dash-hero-chip.is-night[href=?]", all_drive_sessions_path(kind: "night")
  end

  test "should get new" do
    # Complete any in-progress sessions first
    @user.drive_sessions.in_progress.destroy_all
    get new_drive_session_url
    assert_response :success
  end

  test "should not get new when active drive exists" do
    @user.drive_sessions.create!(started_at: Time.current)
    get new_drive_session_url
    assert_redirected_to drive_sessions_url
    assert_equal "You already have an active drive. Please complete it before starting a new one.", flash[:alert]
  end

  test "should create drive_session" do
    @user.drive_sessions.in_progress.destroy_all
    assert_difference("DriveSession.count") do
      post drive_sessions_url, params: {
        drive_session: {
          started_at: Time.current
        }
      }
    end

    assert_redirected_to drive_sessions_url
  end

  test "should not create drive_session when active drive exists" do
    @user.drive_sessions.create!(started_at: Time.current)
    assert_no_difference("DriveSession.count") do
      post drive_sessions_url, params: {
        drive_session: {
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
    assert_response :unprocessable_content
  end

  test "should complete drive_session" do
    in_progress = @user.drive_sessions.create!(
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
    assert_match @user.full_name, response.body
  end

  test "completing a drive left running too long sends the user somewhere they can fix it" do
    # Regression: the max-duration validation made this update fail, the controller
    # discarded the result, and the Stop button silently did nothing — leaving the
    # drive in progress, which also blocks starting a new one.
    @user.drive_sessions.destroy_all
    stale = @user.drive_sessions.create!(started_at: 8.days.ago)

    post complete_drive_session_url(stale)

    assert_redirected_to edit_drive_session_url(stale)
    assert_match(/7 days/, flash[:alert])
    assert_nil stale.reload.ended_at
  end

  test "momentum grid cells are buttons carrying their day's drive summary" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")

    travel_to tz.local(2026, 7, 15, 18, 0, 0) do
      @user.drive_sessions.create!( # 2pm-3pm, all daylight
        started_at: tz.local(2026, 7, 14, 14, 0, 0), ended_at: tz.local(2026, 7, 14, 15, 0, 0)
      )
      @user.drive_sessions.create!( # 9pm-10pm, all dark
        started_at: tz.local(2026, 7, 14, 21, 0, 0), ended_at: tz.local(2026, 7, 14, 22, 0, 0)
      )
      @user.drive_sessions.create!( # 7:30-9pm crosses sunset: the signature case
        started_at: tz.local(2026, 7, 13, 19, 30, 0), ended_at: tz.local(2026, 7, 13, 21, 0, 0)
      )

      get drive_sessions_url
    end

    cell = css_select("button.activity-cell[data-action='day-modal#open']").find do |node|
      JSON.parse(node["data-day-summary"])["count"].to_i == 2
    end
    assert cell, "expected a grid cell carrying the two-drive day"

    summary = JSON.parse(cell["data-day-summary"])
    assert_equal "Tuesday, July 14, 2026", summary["label"]
    assert_equal "2 hrs", summary["total"]
    assert_equal "1 hr", summary["day"]
    assert_equal "1 hr", summary["night"]
    assert_equal %w[day night], summary["drives"].map { |d| d["kind"] }
    assert_equal "2:00 PM – 3:00 PM", summary["drives"].first["time"]
    assert_equal "both", cell["class"][/state-(\w+)/, 1]
    assert_equal "July 14, 2 drives, 2 hrs", cell["aria-label"]

    # A single drive that straddles sunset is "mixed" on its own, and paints the
    # day both colours without needing a second drive.
    crossing = css_select("button.activity-cell").map { |n| JSON.parse(n["data-day-summary"]) }
                                                 .find { |s| s["label"].start_with?("Monday, July 13") }
    assert_equal [ "mixed" ], crossing["drives"].map { |d| d["kind"] }
    assert crossing["day"], "a mixed day reports a day total"
    assert crossing["night"], "a mixed day reports a night total"
  end

  test "a day with only daylight driving omits the night total instead of reporting zero" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")

    travel_to tz.local(2026, 7, 15, 18, 0, 0) do
      @user.drive_sessions.create!(
        started_at: tz.local(2026, 7, 14, 14, 0, 0), ended_at: tz.local(2026, 7, 14, 15, 0, 0)
      )
      get drive_sessions_url
    end

    summary = css_select("button.activity-cell").map { |n| JSON.parse(n["data-day-summary"]) }
                                                .find { |s| s["count"].to_i == 1 }
    assert_equal "1 hr", summary["day"]
    assert_nil summary["night"], "a zero night total must be omitted, not rendered as 0 hrs"
  end

  test "a day with no drives still opens, and future days are not clickable" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago")
    tz = ActiveSupport::TimeZone.new("America/Chicago")

    travel_to tz.local(2026, 7, 15, 18, 0, 0) do
      get drive_sessions_url
    end

    empty = css_select("button.activity-cell").map { |n| JSON.parse(n["data-day-summary"]) }.first
    assert_equal 0, empty["count"]
    assert_empty empty["drives"]
    assert_nil empty["day"], "a driveless day has no day total row"

    # Future cells stay inert divs — nothing to summarise yet.
    assert_select "div.activity-cell.is-future"
    assert_select "div.activity-cell.is-future[data-day-summary]", false
    assert_select "div.activity-cell.is-future[data-action]", false
  end

  test "a drive that crosses sunset carries its split into the detail modal" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    drive = @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 16, 0, 0),
      ended_at: tz.local(2024, 12, 15, 17, 0, 0)
    )
    assert drive.day_and_night?, "4pm-5pm on Dec 15 should straddle sunset"

    get all_drive_sessions_url
    row = css_select("#drive_session_#{drive.id}").first

    assert_equal "mixed", row["data-drive-kind"]
    assert_equal "Day & night drive", row["data-drive-kind-label"]
    assert_select "##{dom_id(drive)} .drive-row-badge.is-mixed .icon-sunset"
    assert_select "dialog.drive-modal .drive-modal-badge-mixed .icon-sunset"
    assert_equal "#{drive.night_minutes} mins", row["data-drive-night-duration"]
    assert_equal "#{drive.duration_minutes - drive.night_minutes} mins", row["data-drive-day-duration"]
    assert_select "[data-drive-modal-target=split]", 1
  end

  test "CSV export reports day and night hours that sum to the duration" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    # 4pm-5pm on Dec 15 crosses sunset at 16:20: ~0.33h day, ~0.67h night.
    @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 16, 0, 0),
      ended_at: tz.local(2024, 12, 15, 17, 0, 0)
    )

    get export_drive_sessions_url(format: :csv)
    rows = CSV.parse(response.body, headers: true)

    assert_equal [ "Duration (hours)", "Day (hours)", "Night (hours)" ], rows.headers[3, 3]
    assert_in_delta 0.33, rows.first["Day (hours)"].to_f, 0.05
    assert_in_delta 0.67, rows.first["Night (hours)"].to_f, 0.05
    assert_in_delta rows.first["Duration (hours)"].to_f,
                    rows.first["Day (hours)"].to_f + rows.first["Night (hours)"].to_f, 0.01
  end

  test "index displays statistics" do
    get drive_sessions_url
    assert_response :success
    assert_select "div", /hours/i
  end

  test "index renders the redesigned dashboard components" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    # a completed day drive with notes -> exercises the day badge + note-as-subtitle
    @user.drive_sessions.create!(started_at: tz.local(2026, 7, 6, 14, 0, 0), ended_at: tz.local(2026, 7, 6, 15, 0, 0), notes: "Sunny afternoon run")

    get drive_sessions_url
    assert_response :success
    assert_select ".dash-hero .dash-hero-number"          # hero renders
    assert_select ".dash-hero-progress .dash-hero-bar-day" # day/night progress bar
    assert_select ".activity-card .activity-grid .activity-cell", minimum: 21 # 3-week grid
    assert_select ".drive-list .drive-row"                 # icon-led recent row
    assert_select ".drive-row-badge.is-day"                # day badge
    assert_select ".drive-row-sub", text: "Sunny afternoon run" # notes render as subtitle
    # rows carry the data the detail modal is populated from on click
    assert_select ".drive-row[data-action*=?]", "drive-modal#open"
    assert_select ".drive-row[data-drive-notes=?]", "Sunny afternoon run"
    assert_select ".drive-row[data-drive-driver=?]", @user.full_name
    assert_select "dialog.drive-modal [data-drive-modal-target='notes']" # shared modal present
  end

  test "all uses pagination" do
    # Create enough sessions to trigger pagination
    20.times do |i|
      @user.drive_sessions.create!(
        started_at: (i + 1).hours.ago,
        ended_at: i.hours.ago
      )
    end

    get all_drive_sessions_url
    assert_response :success
  end

  test "all filters by kind, keeping a sunset-crossing drive under both" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    build = ->(from, to) do
      @user.drive_sessions.create!(
        started_at: tz.local(2024, 12, 15, from, 0, 0),
        ended_at: tz.local(2024, 12, 15, to, 0, 0)
      )
    end
    day = build.call(12, 13)
    night = build.call(18, 19)
    mixed = build.call(16, 17) # crosses sunset at 16:20

    get all_drive_sessions_url
    assert_select ".drive-row", 3

    get all_drive_sessions_url(kind: "day")
    assert_select "##{dom_id(day)}"
    assert_select "##{dom_id(mixed)}"
    assert_select "##{dom_id(night)}", false, "a pure night drive has no daytime hours"
    assert_select ".kind-filter-tab.is-day.is-active[aria-current=?]", "page"
    assert_select "##{dom_id(day)} .drive-row-badge.is-day .icon-sun"
    assert_select "##{dom_id(night)} .drive-row-badge.is-night .icon-moon", false

    get all_drive_sessions_url(kind: "night")
    assert_select "##{dom_id(night)}"
    assert_select "##{dom_id(mixed)}"
    assert_select "##{dom_id(day)}", false, "a pure day drive has no night hours"
    assert_select "##{dom_id(night)} .drive-row-badge.is-night .icon-moon"
  end

  test "an empty filter says which filter came up empty" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    @user.drive_sessions.create!(
      started_at: tz.local(2024, 12, 15, 12, 0, 0),
      ended_at: tz.local(2024, 12, 15, 13, 0, 0)
    )

    get all_drive_sessions_url(kind: "night")
    assert_select ".empty-state", text: /No drives with night hours/

    get all_drive_sessions_url(kind: "day")
    assert_select ".empty-state", false, "the day filter has a drive to show"
  end

  test "the log renders its list even when empty, so a live drive has somewhere to land" do
    @user.drive_sessions.destroy_all

    get all_drive_sessions_url(kind: "night")
    assert_select "#sessions-list-night"
    assert_select ".empty-state", text: /No drives with night hours/
  end

  test "all ignores an unrecognized kind rather than returning nothing" do
    get all_drive_sessions_url(kind: "'; DROP TABLE drive_sessions; --")

    assert_response :success
    assert_select ".kind-filter-tab.is-all.is-active"
    assert_select "##{dom_id(@drive_session)}"
  end

  test "the active filter survives Load More" do
    @user.drive_sessions.destroy_all
    @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
    tz = ActiveSupport::TimeZone.new("America/Chicago")
    # Pinned to midday so all 25 are day drives and the filter still pages.
    25.times do |i|
      date = Date.new(2024, 12, 1) + i
      @user.drive_sessions.create!(
        started_at: tz.local(date.year, date.month, date.day, 12, 0, 0),
        ended_at: tz.local(date.year, date.month, date.day, 13, 0, 0)
      )
    end

    get all_drive_sessions_url(kind: "day")
    assert_response :success
    assert_select "a.load-more[href*=?]", "kind=day"
  end

  test "Load More link disables Turbo hover prefetch" do
    # More than one page so the Load More link renders.
    25.times do |i|
      @user.drive_sessions.create!(started_at: (i + 2).hours.ago, ended_at: (i + 1).hours.ago)
    end

    get all_drive_sessions_url
    assert_response :success
    # Hovering must not prefetch the next page; the attribute is what disables it.
    assert_select "a.load-more[data-turbo-frame='sessions-pagination'][data-turbo-prefetch='false']"
  end

  test "Load More frame request appends the next page as a turbo stream" do
    25.times do |i|
      @user.drive_sessions.create!(started_at: (i + 2).hours.ago, ended_at: (i + 1).hours.ago)
    end

    get all_drive_sessions_url(page: 2), headers: { "Turbo-Frame" => "sessions-pagination" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match(/turbo-stream action="append" target="sessions-list-all"/, response.body)
    assert_match(/turbo-stream action="update" target="sessions-pagination"/, response.body)
  end

  test "should require authentication" do
    delete session_url
    get drive_sessions_url
    assert_redirected_to new_session_url
  end

  test "should only show current user's drive sessions" do
    other_user = users(:two)
    other_session = other_user.drive_sessions.create!(
      started_at: 1.hour.ago,
      ended_at: Time.current
    )

    get drive_sessions_url
    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(other_session)}", count: 0
  end
end
