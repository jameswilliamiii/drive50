require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # The zone every system test reasons in. Pinning the browser to it does two
  # things: the timezone detector posts a value that already matches the stored
  # one, so timezones#update short-circuits instead of writing to the users table
  # from the Puma thread while the test thread writes its own fixtures (which
  # deadlocks SQLite on a slow box) — and the grid's local dates stop depending on
  # whatever zone the machine running the suite happens to be in.
  BROWSER_TIME_ZONE = "America/Chicago".freeze

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup do
    page.driver.browser.execute_cdp(
      "Emulation.setTimezoneOverride", timezoneId: BROWSER_TIME_ZONE
    )
  end

  private

  def browser_zone
    ActiveSupport::TimeZone.new(BROWSER_TIME_ZONE)
  end

  # "Today" as the browser and the grid both see it, rather than in the Rails
  # default zone, which is UTC and rolls over at a different moment.
  def today_in_browser_zone
    Time.current.in_time_zone(browser_zone).to_date
  end
end
