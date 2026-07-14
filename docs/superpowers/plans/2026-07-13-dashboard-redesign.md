# Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Drive50 dashboard (`drive_sessions#index`) as one cohesive "dusk" system — a gradient hero (total-hours + derived insights), a streak-led activity card with a 3-week day/night grid, and icon-led recent-drive rows — fully theme-aware and mobile-first.

**Architecture:** All new derived statistics are computed server-side in the `DriveSessionStatistics` concern and the `DriveSession` model (timezone-aware), bundled through the existing `statistics_for` entry point. The view layer is reorganized into focused partials rendered inside the existing Turbo Stream broadcast targets (`#progress-summary`, `#recent-drives-table`), so real-time updates keep working. Color/theme is driven by CSS custom properties added to `00-variables.css`, so light/dark is automatic. All new CSS is appended to the already-loaded `cards.css` (Propshaft serves the stylesheets individually; there is no `app.css` bundle to register a new file with).

**Tech Stack:** Rails 8.1, Minitest, Hotwire (Turbo Streams + Stimulus), Propshaft, plain CSS with custom properties, inline SVG via `IconHelper`.

**Approved design spec:** `docs/superpowers/specs/2026-07-13-dashboard-redesign-design.md`

---

## Reference: existing code this plan touches

- `app/models/concerns/drive_session_statistics.rb` — `statistics_for(user_or_relation)` returns `{total_hours, night_hours, hours_needed, night_hours_needed, in_progress}`.
- `app/models/drive_session.rb` — `HOURS_NEEDED=50`, `NIGHT_HOURS_NEEDED=10`; scopes `completed`, `in_progress`, `night_drives`, `ordered`; `self.activity_by_date`; broadcast callbacks (`broadcast_create`, `broadcast_update`, `broadcast_destroy`, `broadcast_progress_summary`, `broadcast_recent_drives_table`).
- `app/controllers/drive_sessions_controller.rb` — `index` (dashboard) and `all` both call `statistics_for`.
- Views: `_progress_summary`, `_stat_card`, `_activity_calendar`, `_in_progress_drive`, `_recent_drives_table`, `_session_row`, `_table_header`, `index.html.erb`, `destroy.turbo_stream.erb`, `all.html.erb`.
- Helpers: `drive_session_helper.rb` (`format_duration`, `circular_progress`, `activity_calendar_data`), `icon_helper.rb` (`icon_sun`, `icon_moon`, `icon_dots`, `icon_check`, `icon_info`).
- CSS: `00-variables.css` (tokens + dark overrides), `cards.css` (dashboard), `card-menu.css` (mobile bottom sheet — reused untouched).
- JS: `activity_calendar_controller.js` (tap-a-day → toast on mobile).

**Shared-partial guardrail (from spec):** `_session_row.html.erb` and `_table_header.html.erb` are used by the out-of-scope All-drives page and by `<tr>`/`sessions-tbody` broadcasts. **Do not modify them.** The dashboard gets its own row partials.

**Test conventions:** Minitest, `require "test_helper"`, fixtures `users(:one)`/`users(:two)`, `include ActiveJob::TestHelper` where drives are created (creation enqueues a reminder job). Use `travel_to` for time-dependent tests. Set `@user.update!(timezone: "...")` when timezone matters.

**CRITICAL — `is_night_drive` is derived, never respected on input.** `DriveSession` has `before_save :determine_night_drive`, which recomputes `is_night_drive` from the actual local start/end clock times (via a solar sunrise/sunset calc) whenever `started_at`/`ended_at` change. Passing `is_night_drive:` to `create!` is **silently overwritten**. To make a genuine *night* drive in a test you must use real night-time local clock times and set the user's coordinates, exactly like the existing night-drive tests:

```ruby
@user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
tz = ActiveSupport::TimeZone.new("America/Chicago")
# night: 9-10pm local; day: 2-3pm local
night = @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 6, 21, 0, 0), ended_at: tz.local(2026, 7, 6, 22, 0, 0))
day   = @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 6, 14, 0, 0), ended_at: tz.local(2026, 7, 6, 15, 0, 0))
```

Tests that only depend on a drive's **date** (streaks, active days, weekly hours) can use plain afternoon times; only day-vs-night tests need the coordinates + night clock times.

---

## Task 1: Add design tokens to CSS variables

**Files:**
- Modify: `app/assets/stylesheets/00-variables.css`

New tokens power the hero gradient, the activity grid day/night shades, the "today" ring, and the recent-drive badges. Adding them as tokens (with dark overrides) makes every downstream component theme-aware automatically.

- [ ] **Step 1: Add tokens to the light `:root` block**

In `00-variables.css`, inside the default `:root { ... }` block (near the other color tokens), add:

```css
  /* Dashboard redesign — day/night dusk system */
  --hero-gradient: radial-gradient(135% 135% at 15% -10%, #4f46e5 0%, #362e8f 45%, #1c1b40 100%);
  --hero-horizon: radial-gradient(120% 100% at 50% 145%, rgba(251,191,36,.30) 0%, rgba(245,158,11,.10) 38%, transparent 68%);
  --hero-border: transparent;
  --hero-shadow: 0 12px 32px -14px rgba(30,27,75,.55);

  --activity-day: #f59e0b;
  --activity-night: #6366f1;
  --activity-both: linear-gradient(135deg, #f59e0b 0 50%, #6366f1 50% 100%);
  --activity-empty-bg: #f1f5f9;
  --activity-empty-border: #e2e8f0;
  --activity-today-ring: #2563eb;
  --streak-color: #f59e0b;

  --recent-badge-day-bg: #fef3c7;
  --recent-badge-day-fg: #f59e0b;
  --recent-badge-night-bg: #eef2ff;
  --recent-badge-night-fg: #6366f1;
```

- [ ] **Step 2: Add dark overrides to the explicit dark block**

Inside the existing `:root[data-theme="dark"], body[data-theme="dark"] { ... }` block, add:

```css
  /* Dashboard redesign — dark */
  --hero-gradient: radial-gradient(135% 135% at 15% -10%, #2b2870 0%, #1f1c49 46%, #121129 100%);
  --hero-horizon: radial-gradient(120% 100% at 50% 150%, rgba(251,191,36,.17) 0%, rgba(245,158,11,.05) 40%, transparent 68%);
  --hero-border: rgba(129,140,248,.16);
  --hero-shadow: 0 10px 30px -18px rgba(0,0,0,.8);

  --activity-day: #fbbf24;
  --activity-night: #a5b4fc;
  --activity-both: linear-gradient(135deg, #fbbf24 0 50%, #a5b4fc 50% 100%);
  --activity-empty-bg: #1e293b;
  --activity-empty-border: #334155;
  --activity-today-ring: #60a5fa;

  --recent-badge-day-bg: #78350f;
  --recent-badge-day-fg: #fbbf24;
  --recent-badge-night-bg: #312e81;
  --recent-badge-night-fg: #a5b4fc;
```

- [ ] **Step 3: Add the same dark overrides to the system-preference block**

The file also has `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]):not([data-theme="dark"]) { ... } }`, which currently overrides only a subset of tokens. Add the **same** dark token block from Step 2 inside that `:root:not(...)` rule, so system-dark users (no explicit toggle) get the dark dusk treatment too.

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/00-variables.css
git commit -m "feat(dashboard): add dusk design tokens with light/dark variants"
```

---

## Task 2: Derived hour statistics (day hours, drive count, weekly hours)

**Files:**
- Modify: `app/models/concerns/drive_session_statistics.rb`
- Test: `test/models/drive_session_test.rb`

These are simple aggregate helpers. Add them as class methods on the concern so they are callable on a relation (like the existing `activity_by_date`), scoped by `completed`.

- [ ] **Step 1: Write failing tests**

Add to `test/models/drive_session_test.rb`:

```ruby
# --- Derived statistics: hours ---
test "day_hours excludes night drives" do
  @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
  tz = ActiveSupport::TimeZone.new("America/Chicago")
  # is_night_drive is derived from the clock times below, not passed in.
  @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 6, 14, 0, 0), ended_at: tz.local(2026, 7, 6, 15, 0, 0)) # day, 1h
  @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 6, 21, 0, 0), ended_at: tz.local(2026, 7, 6, 22, 0, 0)) # night, 1h
  assert_in_delta 1.0, @user.drive_sessions.day_hours, 0.01
end

test "drives_count counts only completed drives" do
  @user.drive_sessions.create!(driver_name: "D", started_at: 2.hours.ago, ended_at: 1.hour.ago)
  @user.drive_sessions.create!(driver_name: "D", started_at: 30.minutes.ago) # in progress
  assert_equal 1, @user.drive_sessions.drives_count
end

test "hours_in_week sums the given calendar week (Sunday start) in the user timezone" do
  @user.update!(timezone: "America/Chicago")
  travel_to Time.zone.parse("2026-07-15 12:00 UTC") do # Wed 2026-07-15
    # this week (Sun 07-12 .. Sat 07-18): one 1h drive
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-13 15:00", ended_at: "2026-07-13 16:00")
    # last week (Sun 07-05 .. Sat 07-11): one 2h drive
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-08 15:00", ended_at: "2026-07-08 17:00")
    assert_in_delta 1.0, @user.drive_sessions.hours_in_week(0, timezone: "America/Chicago"), 0.01
    assert_in_delta 2.0, @user.drive_sessions.hours_in_week(1, timezone: "America/Chicago"), 0.01
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/drive_session_test.rb -n "/day_hours|drives_count|hours_in_week/"`
Expected: FAIL (`NoMethodError: undefined method 'day_hours'`).

- [ ] **Step 3: Implement the methods**

In `drive_session_statistics.rb`, inside `class_methods do ... end`, add:

```ruby
def day_hours
  completed.where(is_night_drive: false).sum(:duration_minutes) / 60.0
end

def drives_count
  completed.count
end

# weeks_ago: 0 = current calendar week, 1 = previous, etc. Sunday-start, in the given tz.
def hours_in_week(weeks_ago, timezone: "UTC")
  tz = ActiveSupport::TimeZone[timezone || "UTC"]
  today = Time.current.in_time_zone(tz).to_date
  start_date = today - today.wday - (weeks_ago * 7)
  start_dt = tz.local(start_date.year, start_date.month, start_date.day)
  end_dt = start_dt + 7.days
  completed.where(started_at: start_dt...end_dt).sum(:duration_minutes) / 60.0
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/drive_session_test.rb -n "/day_hours|drives_count|hours_in_week/"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/concerns/drive_session_statistics.rb test/models/drive_session_test.rb
git commit -m "feat(dashboard): add day_hours, drives_count, hours_in_week stats"
```

---

## Task 3: Streak and active-days statistics

**Files:**
- Modify: `app/models/concerns/drive_session_statistics.rb`
- Test: `test/models/drive_session_test.rb`

Streaks and active-day counts operate on the set of distinct local dates that have ≥1 completed drive.

- [ ] **Step 1: Write failing tests**

```ruby
# --- Derived statistics: streaks ---
test "current_streak counts consecutive days ending today or yesterday" do
  @user.update!(timezone: "America/Chicago")
  travel_to Time.zone.parse("2026-07-15 18:00 UTC") do # Wed 07-15
    [ "2026-07-13", "2026-07-14", "2026-07-15" ].each do |d|
      @user.drive_sessions.create!(driver_name: "D", started_at: "#{d} 15:00", ended_at: "#{d} 16:00")
    end
    assert_equal 3, @user.drive_sessions.current_streak(timezone: "America/Chicago")
  end
end

test "current_streak is zero when the last drive is older than yesterday" do
  @user.update!(timezone: "America/Chicago")
  travel_to Time.zone.parse("2026-07-15 18:00 UTC") do
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-10 15:00", ended_at: "2026-07-10 16:00")
    assert_equal 0, @user.drive_sessions.current_streak(timezone: "America/Chicago")
  end
end

test "best_streak returns the longest consecutive run ever" do
  @user.update!(timezone: "America/Chicago")
  [ "2026-06-01", "2026-06-02", "2026-06-03", "2026-06-10" ].each do |d|
    @user.drive_sessions.create!(driver_name: "D", started_at: "#{d} 15:00", ended_at: "#{d} 16:00")
  end
  assert_equal 3, @user.drive_sessions.best_streak(timezone: "America/Chicago")
end

test "active_day_count counts distinct active days within the trailing window" do
  @user.update!(timezone: "America/Chicago")
  travel_to Time.zone.parse("2026-07-21 18:00 UTC") do
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-20 15:00", ended_at: "2026-07-20 16:00")
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-20 20:00", ended_at: "2026-07-20 21:00") # same day
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-06-01 15:00", ended_at: "2026-06-01 16:00") # outside 21d
    assert_equal 1, @user.drive_sessions.active_day_count(days: 21, timezone: "America/Chicago")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/drive_session_test.rb -n "/current_streak|best_streak|active_day_count/"`
Expected: FAIL.

- [ ] **Step 3: Implement the methods**

Add to `class_methods do`:

```ruby
# Distinct local dates (user tz) that have at least one completed drive, ascending.
def active_dates(timezone: "UTC")
  tz = ActiveSupport::TimeZone[timezone || "UTC"]
  completed.pluck(:started_at).map { |t| t.in_time_zone(tz).to_date }.uniq.sort
end

def active_day_count(days: 21, timezone: "UTC")
  tz = ActiveSupport::TimeZone[timezone || "UTC"]
  today = Time.current.in_time_zone(tz).to_date
  cutoff = today - (days - 1)
  active_dates(timezone: timezone).count { |d| d >= cutoff && d <= today }
end

def current_streak(timezone: "UTC")
  tz = ActiveSupport::TimeZone[timezone || "UTC"]
  today = Time.current.in_time_zone(tz).to_date
  dates = active_dates(timezone: timezone).to_set
  return 0 if dates.empty?

  cursor = dates.include?(today) ? today : today - 1
  return 0 unless dates.include?(cursor)

  streak = 0
  while dates.include?(cursor)
    streak += 1
    cursor -= 1
  end
  streak
end

def best_streak(timezone: "UTC")
  best = 0
  run = 0
  prev = nil
  active_dates(timezone: timezone).each do |date|
    run = (prev && date == prev + 1) ? run + 1 : 1
    best = run if run > best
    prev = date
  end
  best
end
```

Note: `require "set"` is not needed on Rails 8 (Set is autoloaded), but `.to_set` is available via ActiveSupport.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/drive_session_test.rb -n "/current_streak|best_streak|active_day_count/"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/concerns/drive_session_statistics.rb test/models/drive_session_test.rb
git commit -m "feat(dashboard): add streak and active-day statistics"
```

---

## Task 4: Weekly pace and projected finish

**Files:**
- Modify: `app/models/concerns/drive_session_statistics.rb`
- Test: `test/models/drive_session_test.rb`

`projected_finish` returns a human label ("Early October", "Keep driving", "Complete") so the view stays dumb.

- [ ] **Step 1: Write failing tests**

```ruby
# --- Derived statistics: pace & projection ---
test "weekly_pace averages recent hours over weeks of history (capped at 4)" do
  @user.update!(timezone: "America/Chicago")
  travel_to Time.zone.parse("2026-07-15 18:00 UTC") do
    # 15 days of history -> round(15/7)=2 weeks; 6 total recent hours -> 3.0/wk
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-01 15:00", ended_at: "2026-07-01 18:00") # 3h
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-14 15:00", ended_at: "2026-07-14 18:00") # 3h
    assert_in_delta 3.0, @user.drive_sessions.weekly_pace(timezone: "America/Chicago"), 0.1
  end
end

test "weekly_pace is zero with no drives" do
  assert_equal 0.0, @user.drive_sessions.weekly_pace(timezone: "America/Chicago")
end

test "projected_finish returns a month label when on pace" do
  @user.update!(timezone: "America/Chicago")
  travel_to Time.zone.parse("2026-07-15 18:00 UTC") do
    # ~49h remaining at ~3h/wk -> many weeks out; just assert it produces an Early/Mid/Late Month string
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-01 15:00", ended_at: "2026-07-01 18:00")
    @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-14 15:00", ended_at: "2026-07-14 18:00")
    label = @user.drive_sessions.projected_finish(timezone: "America/Chicago")
    assert_match(/\A(Early|Mid|Late) [A-Z][a-z]+\z/, label)
  end
end

test "projected_finish is 'Keep driving' when pace is zero" do
  assert_equal "Keep driving", @user.drive_sessions.projected_finish(timezone: "America/Chicago")
end

test "projected_finish is 'Complete' when the goal is met" do
  @user.update!(timezone: "America/Chicago")
  @user.drive_sessions.create!(driver_name: "D", started_at: "2026-07-01 08:00", ended_at: "2026-07-03 10:00") # 50h
  assert_equal "Complete", @user.drive_sessions.projected_finish(timezone: "America/Chicago")
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/drive_session_test.rb -n "/weekly_pace|projected_finish/"`
Expected: FAIL.

- [ ] **Step 3: Implement the methods**

Add to `class_methods do`:

```ruby
def weekly_pace(timezone: "UTC")
  tz = ActiveSupport::TimeZone[timezone || "UTC"]
  first = completed.minimum(:started_at)
  return 0.0 if first.nil?

  recent_hours = completed.where("started_at >= ?", 28.days.ago).sum(:duration_minutes) / 60.0
  today = Time.current.in_time_zone(tz).to_date
  days_of_history = (today - first.in_time_zone(tz).to_date).to_i + 1
  weeks = [ [ (days_of_history / 7.0).round, 4 ].min, 1 ].max
  (recent_hours / weeks).round(1)
end

def projected_finish(timezone: "UTC")
  remaining = [ DriveSession::HOURS_NEEDED - (completed.sum(:duration_minutes) / 60.0), 0 ].max
  return "Complete" if remaining <= 0

  pace = weekly_pace(timezone: timezone)
  return "Keep driving" if pace <= 0

  weeks_left = remaining / pace
  date = Date.current + (weeks_left * 7).ceil
  part = date.day <= 10 ? "Early" : (date.day <= 20 ? "Mid" : "Late")
  "#{part} #{date.strftime('%B')}"
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/drive_session_test.rb -n "/weekly_pace|projected_finish/"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/concerns/drive_session_statistics.rb test/models/drive_session_test.rb
git commit -m "feat(dashboard): add weekly_pace and projected_finish"
```

---

## Task 5: Bundle stats into `statistics_for` and wire the controller

**Files:**
- Modify: `app/models/concerns/drive_session_statistics.rb`
- Modify: `app/controllers/drive_sessions_controller.rb:4-16` (the `index` action)
- Test: `test/models/drive_session_test.rb`

- [ ] **Step 1: Write a failing test for the bundled hash**

```ruby
test "statistics_for includes the new dashboard metrics" do
  @user.update!(timezone: "America/Chicago")
  @user.drive_sessions.create!(driver_name: "D", started_at: 2.hours.ago, ended_at: 1.hour.ago)
  stats = DriveSession.statistics_for(@user, timezone: "America/Chicago")
  [ :day_hours, :drives_count, :this_week_hours, :last_week_hours,
    :active_days, :current_streak, :best_streak, :weekly_pace, :projected_finish ].each do |key|
    assert stats.key?(key), "expected statistics_for to include #{key}"
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/models/drive_session_test.rb -n "/statistics_for includes the new/"`
Expected: FAIL (missing keys).

- [ ] **Step 3: Extend `statistics_for`**

Replace the `statistics_for` method with:

```ruby
def statistics_for(user_or_relation, timezone: "UTC")
  relation = user_or_relation.is_a?(ActiveRecord::Relation) ? user_or_relation : user_or_relation.drive_sessions

  {
    total_hours: relation.completed.sum(:duration_minutes) / 60.0,
    night_hours: relation.night_drives.completed.sum(:duration_minutes) / 60.0,
    day_hours: relation.day_hours,
    hours_needed: [ DriveSession::HOURS_NEEDED - (relation.completed.sum(:duration_minutes) / 60.0), 0 ].max,
    night_hours_needed: [ DriveSession::NIGHT_HOURS_NEEDED - (relation.night_drives.completed.sum(:duration_minutes) / 60.0), 0 ].max,
    drives_count: relation.drives_count,
    in_progress: relation.in_progress.first,
    this_week_hours: relation.hours_in_week(0, timezone: timezone),
    last_week_hours: relation.hours_in_week(1, timezone: timezone),
    active_days: relation.active_day_count(days: 21, timezone: timezone),
    current_streak: relation.current_streak(timezone: timezone),
    best_streak: relation.best_streak(timezone: timezone),
    weekly_pace: relation.weekly_pace(timezone: timezone),
    projected_finish: relation.projected_finish(timezone: timezone)
  }
end
```

Note: `all.html.erb` calls `statistics_for(Current.user)` with no timezone; the default `"UTC"` keeps it working and it ignores the extra keys. Leave the `all` action unchanged.

- [ ] **Step 4: Run to verify it passes**

Run: `bin/rails test test/models/drive_session_test.rb -n "/statistics_for includes the new/"`
Expected: PASS.

- [ ] **Step 5: Update the `index` action**

In `app/controllers/drive_sessions_controller.rb`, replace the body of `index` with:

```ruby
def index
  tz = Current.user.timezone || "UTC"
  user_sessions = Current.user.drive_sessions

  @recent_sessions = user_sessions.completed.ordered.limit(3)
  @stats = DriveSession.statistics_for(Current.user, timezone: tz)
  @activity_states = user_sessions.activity_day_states(timezone: tz)
end
```

(`activity_day_states` is added in Task 6; this line will raise until then — that is fine, Task 6 immediately follows and Task 7 is the first task that renders the view.)

- [ ] **Step 6: Commit**

```bash
git add app/models/concerns/drive_session_statistics.rb app/controllers/drive_sessions_controller.rb test/models/drive_session_test.rb
git commit -m "feat(dashboard): bundle derived stats into statistics_for and wire index"
```

---

## Task 6: Activity day/night states + calendar helper

**Files:**
- Modify: `app/models/drive_session.rb` (add `self.activity_day_states` near `self.activity_by_date`)
- Modify: `app/helpers/drive_session_helper.rb` (add `dashboard_activity_days`)
- Test: `test/models/drive_session_test.rb`, `test/helpers/drive_session_helper_test.rb`

- [ ] **Step 1: Write failing model test**

```ruby
test "activity_day_states maps each active day to :day, :night, or :both" do
  @user.update!(timezone: "America/Chicago", latitude: 41.8781, longitude: -87.6298)
  tz = ActiveSupport::TimeZone.new("America/Chicago")
  travel_to tz.local(2026, 7, 15, 18, 0, 0) do # Wed; grid window 06-28..07-18
    # is_night_drive is derived from the clock times, not passed in.
    @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 14, 14, 0, 0), ended_at: tz.local(2026, 7, 14, 15, 0, 0)) # day only
    @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 13, 21, 0, 0), ended_at: tz.local(2026, 7, 13, 22, 0, 0)) # night only
    @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 12, 14, 0, 0), ended_at: tz.local(2026, 7, 12, 15, 0, 0)) # day part of "both"
    @user.drive_sessions.create!(driver_name: "D", started_at: tz.local(2026, 7, 12, 21, 0, 0), ended_at: tz.local(2026, 7, 12, 22, 0, 0)) # night part of "both"
    states = @user.drive_sessions.activity_day_states(timezone: "America/Chicago")
    assert_equal :day,   states[Date.new(2026, 7, 14)]
    assert_equal :night, states[Date.new(2026, 7, 13)]
    assert_equal :both,  states[Date.new(2026, 7, 12)]
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/models/drive_session_test.rb -n "/activity_day_states/"`
Expected: FAIL.

- [ ] **Step 3: Implement `activity_day_states`**

In `app/models/drive_session.rb`, after `self.activity_by_date`, add:

```ruby
# Returns { Date => :day | :night | :both } for every day with a completed drive
# in the 3 Sunday-aligned weeks ending with the current week.
def self.activity_day_states(timezone: "UTC")
  tz = ActiveSupport::TimeZone[timezone || "UTC"]
  today = Time.current.in_time_zone(tz).to_date
  start_of_week = today - today.wday
  range_start = start_of_week - 14
  start_datetime = tz.local(range_start.year, range_start.month, range_start.day)

  states = Hash.new { |h, k| h[k] = { day: false, night: false } }
  completed.where("started_at >= ?", start_datetime).find_each do |session|
    date = session.started_at.in_time_zone(tz).to_date
    session.is_night_drive ? states[date][:night] = true : states[date][:day] = true
  end

  states.transform_values do |v|
    if v[:day] && v[:night] then :both
    elsif v[:night] then :night
    elsif v[:day] then :day
    else :none
    end
  end
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `bin/rails test test/models/drive_session_test.rb -n "/activity_day_states/"`
Expected: PASS.

- [ ] **Step 5: Write failing helper test**

In `test/helpers/drive_session_helper_test.rb` (class `DriveSessionHelperTest < ActionView::TestCase`), add:

```ruby
test "dashboard_activity_days returns 21 Sunday-aligned cells with today and future flags" do
  travel_to Time.zone.parse("2026-07-15 18:00 UTC") do # Wed
    states = { Date.new(2026, 7, 14) => :day }
    days = dashboard_activity_days(states, timezone: "America/Chicago")
    assert_equal 21, days.length
    assert_equal 0, days.first[:date].wday # first cell is a Sunday
    assert(days.any? { |d| d[:today] })
    today_cell = days.find { |d| d[:today] }
    assert_equal Date.new(2026, 7, 15), today_cell[:date]
    assert_equal :day, days.find { |d| d[:date] == Date.new(2026, 7, 14) }[:state]
    assert(days.any? { |d| d[:future] }) # Thu-Sat of current week
  end
end
```

- [ ] **Step 6: Run to verify it fails**

Run: `bin/rails test test/helpers/drive_session_helper_test.rb -n "/dashboard_activity_days/"`
Expected: FAIL.

- [ ] **Step 7: Implement `dashboard_activity_days`**

In `app/helpers/drive_session_helper.rb`, add:

```ruby
# Expands a { Date => state } hash into 21 Sunday-aligned cells (3 weeks).
def dashboard_activity_days(states, timezone: "UTC")
  tz = ActiveSupport::TimeZone[timezone || "UTC"]
  today = Time.current.in_time_zone(tz).to_date
  start_of_week = today - today.wday
  range_start = start_of_week - 14

  (range_start..(start_of_week + 6)).map do |date|
    {
      date: date,
      state: states[date] || :none,
      today: date == today,
      future: date > today
    }
  end
end
```

- [ ] **Step 8: Run to verify it passes**

Run: `bin/rails test test/helpers/drive_session_helper_test.rb -n "/dashboard_activity_days/"`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/models/drive_session.rb app/helpers/drive_session_helper.rb test/models/drive_session_test.rb test/helpers/drive_session_helper_test.rb
git commit -m "feat(dashboard): add activity day/night states and calendar helper"
```

---

## Task 7: Hero partial + progress_summary wrapper + CSS

**Files:**
- Create: `app/views/drive_sessions/_dashboard_hero.html.erb`
- Rewrite: `app/views/drive_sessions/_progress_summary.html.erb`
- Modify: `app/assets/stylesheets/cards.css` (append hero styles)

The `#progress-summary` wrapper stays (it is the Turbo Stream target) and now composes the hero + the activity card (activity partial rewritten in Task 8). It receives `stats:` and `activity_days:` locals.

- [ ] **Step 1: Create the hero partial**

`app/views/drive_sessions/_dashboard_hero.html.erb`:

```erb
<div class="dash-hero">
  <div class="dash-hero-top">
    <div>
      <div class="dash-hero-number"><%= stats[:total_hours].round(1) %></div>
      <div class="dash-hero-caption">of <%= DriveSession::HOURS_NEEDED %> hours · <%= format_duration(stats[:hours_needed]) %> to go</div>
    </div>
    <div class="dash-hero-finish">
      <div class="dash-hero-finish-label">Projected finish</div>
      <div class="dash-hero-finish-value"><%= stats[:projected_finish] %></div>
    </div>
  </div>

  <% goal = DriveSession::HOURS_NEEDED.to_f %>
  <div class="dash-hero-progress">
    <div class="dash-hero-bar dash-hero-bar-day" style="width: <%= [ stats[:day_hours] / goal * 100, 100 ].min %>%"></div>
    <div class="dash-hero-bar dash-hero-bar-night" style="width: <%= [ stats[:night_hours] / goal * 100, 100 ].min %>%"></div>
  </div>

  <div class="dash-hero-chips">
    <div class="dash-hero-chip is-day">
      <span class="dash-hero-chip-key">Day</span>
      <span class="dash-hero-chip-value"><%= stats[:day_hours].round(1) %></span>
    </div>
    <div class="dash-hero-chip is-night">
      <span class="dash-hero-chip-key">Night</span>
      <span class="dash-hero-chip-value"><%= stats[:night_hours].round(1) %> <small>/ <%= DriveSession::NIGHT_HOURS_NEEDED %></small></span>
    </div>
    <div class="dash-hero-chip">
      <span class="dash-hero-chip-key">Pace</span>
      <span class="dash-hero-chip-value"><%= stats[:weekly_pace] %> <small>h/wk</small></span>
    </div>
    <div class="dash-hero-chip">
      <span class="dash-hero-chip-key">Drives</span>
      <span class="dash-hero-chip-value"><%= stats[:drives_count] %></span>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Rewrite `_progress_summary.html.erb`**

```erb
<div id="progress-summary" class="dashboard-summary">
  <%= render "drive_sessions/dashboard_hero", stats: stats %>
  <%= render "drive_sessions/activity_calendar", stats: stats, days: activity_days %>
</div>
```

(The `activity_calendar` partial is rewritten in Task 8. Do not render the dashboard until Task 8 is done — Task 9 wires `index.html.erb`.)

- [ ] **Step 3: Append hero CSS to `cards.css`**

Add at the end of `app/assets/stylesheets/cards.css`:

```css
/* ============================================
   Dashboard redesign — layout
   ============================================ */
.dashboard-summary {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-xl);
}

/* ---- Hero ---- */
.dash-hero {
  position: relative;
  border-radius: var(--border-radius-lg);
  padding: calc(var(--spacing-unit) * 1.75) calc(var(--spacing-unit) * 1.875);
  overflow: hidden;
  color: #fff;
  background: var(--hero-gradient);
  border: 1px solid var(--hero-border);
  box-shadow: var(--hero-shadow);
  font-feature-settings: "tnum" 1;
}
.dash-hero::after {
  content: "";
  position: absolute;
  left: 0; right: 0; bottom: 0;
  height: 55%;
  pointer-events: none;
  background: var(--hero-horizon);
}
.dash-hero > * { position: relative; z-index: 1; }

.dash-hero-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: var(--spacing-lg);
}
.dash-hero-number { font-size: 4.4rem; font-weight: 820; line-height: .82; letter-spacing: -.02em; }
.dash-hero-caption { font-size: .82rem; color: rgba(255,255,255,.72); font-weight: 600; margin-top: 10px; }

.dash-hero-finish { text-align: right; flex-shrink: 0; }
.dash-hero-finish-label { font-size: .64rem; letter-spacing: .06em; text-transform: uppercase; color: rgba(255,255,255,.58); font-weight: 700; }
.dash-hero-finish-value { font-size: 1.1rem; font-weight: 800; margin-top: 4px; white-space: nowrap; }

.dash-hero-progress {
  height: 9px; border-radius: 6px;
  background: rgba(255,255,255,.16);
  display: flex; overflow: hidden;
  margin-top: var(--spacing-xl);
}
.dash-hero-bar-day { background: linear-gradient(90deg,#fcd34d,#f59e0b); }
.dash-hero-bar-night { background: linear-gradient(90deg,#a5b4fc,#818cf8); }

.dash-hero-chips {
  display: grid; grid-template-columns: repeat(4, 1fr);
  gap: var(--spacing-sm); margin-top: var(--spacing-xl);
}
.dash-hero-chip {
  background: rgba(255,255,255,.10);
  border: 1px solid rgba(255,255,255,.15);
  border-radius: var(--border-radius-sm);
  padding: 11px 13px;
  backdrop-filter: blur(8px);
}
.dash-hero-chip-key { display: block; font-size: .66rem; text-transform: uppercase; letter-spacing: .05em; font-weight: 700; color: rgba(255,255,255,.62); }
.dash-hero-chip-value { display: block; font-size: 1.3rem; font-weight: 800; margin-top: 4px; }
.dash-hero-chip-value small { font-size: .72rem; color: rgba(255,255,255,.6); font-weight: 600; }
.dash-hero-chip.is-day .dash-hero-chip-key { color: #fcd34d; }
.dash-hero-chip.is-night .dash-hero-chip-key { color: #c7d2fe; }

@media (max-width: 768px) {
  .dash-hero-top { flex-direction: column; }
  .dash-hero-number { font-size: 3.5rem; }
  .dash-hero-finish {
    text-align: left; width: 100%;
    margin-top: var(--spacing-md);
    padding-top: var(--spacing-md);
    border-top: 1px solid rgba(255,255,255,.14);
  }
  .dash-hero-chips { grid-template-columns: 1fr 1fr; }
}
```

- [ ] **Step 4: Commit**

```bash
git add app/views/drive_sessions/_dashboard_hero.html.erb app/views/drive_sessions/_progress_summary.html.erb app/assets/stylesheets/cards.css
git commit -m "feat(dashboard): add dusk hero partial and styles"
```

---

## Task 8: Activity card partial + Stimulus update + CSS

**Files:**
- Rewrite: `app/views/drive_sessions/_activity_calendar.html.erb`
- Modify: `app/javascript/controllers/activity_calendar_controller.js`
- Modify: `app/assets/stylesheets/cards.css` (append activity styles)

- [ ] **Step 1: Rewrite `_activity_calendar.html.erb`**

Receives `stats:` and `days:` locals.

```erb
<div class="activity-card">
  <div class="activity-card-header">
    <span class="activity-card-title">Driving rhythm</span>
    <span class="activity-card-sub">last 3 weeks</span>
  </div>

  <div class="activity-card-body">
    <div class="activity-statement">
      <div class="activity-streak-number"><%= stats[:current_streak] %></div>
      <div class="activity-streak-label">Day streak</div>
      <p class="activity-sentence">
        You've driven <b><%= stats[:active_days] %> of the last 21</b> days.
      </p>
      <div class="activity-ministats">
        <div class="activity-ministat">
          <div class="activity-ministat-key">This week</div>
          <div class="activity-ministat-value"><%= format_duration(stats[:this_week_hours]) %></div>
        </div>
        <div class="activity-ministat">
          <div class="activity-ministat-key">Last week</div>
          <div class="activity-ministat-value"><%= format_duration(stats[:last_week_hours]) %></div>
        </div>
        <div class="activity-ministat">
          <div class="activity-ministat-key">Best</div>
          <div class="activity-ministat-value"><%= pluralize(stats[:best_streak], "day") %></div>
        </div>
      </div>
    </div>

    <div class="activity-cal" data-controller="activity-calendar">
      <div class="activity-weekdays">
        <% %w[S M T W T F S].each do |label| %><span><%= label %></span><% end %>
      </div>
      <div class="activity-grid">
        <% days.each do |day| %>
          <div class="activity-cell state-<%= day[:state] %><%= " is-today" if day[:today] %><%= " is-future" if day[:future] %>"
               title="<%= day[:date].strftime("%B %d, %Y") %>"
               data-activity-calendar-target="day"
               data-date="<%= day[:date].strftime("%B %d, %Y") %>"
               data-state="<%= day[:state] %>"
               data-action="click->activity-calendar#showDayInfo"></div>
        <% end %>
      </div>
      <div class="activity-legend">
        <span><span class="activity-swatch is-day"></span>Day</span>
        <span><span class="activity-swatch is-night"></span>Night</span>
        <span><span class="activity-swatch is-both"></span>Both</span>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Update the Stimulus controller to read `data-state`**

Replace `showDayInfo` in `app/javascript/controllers/activity_calendar_controller.js`:

```javascript
  showDayInfo(event) {
    const dayElement = event.currentTarget
    const date = dayElement.dataset.date
    const state = dayElement.dataset.state

    const label = {
      day: "day drive",
      night: "night drive",
      both: "day & night drives",
      none: "no drives"
    }[state] || "no drives"

    const isMobile = !window.matchMedia("(hover: hover)").matches
    if (isMobile) {
      this.createToast(`${date}: ${label}`)
    }
  }
```

(`createToast` is unchanged.)

- [ ] **Step 3: Append activity CSS to `cards.css`**

```css
/* ---- Activity card ---- */
.activity-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-lg);
  box-shadow: var(--shadow-sm);
  font-feature-settings: "tnum" 1;
}
.activity-card-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: var(--spacing-lg) calc(var(--spacing-unit) * 1.5) 0;
}
.activity-card-title { font-weight: 700; font-size: 1rem; color: var(--color-text); }
.activity-card-sub { font-size: .78rem; color: var(--color-text-light); font-weight: 600; }

.activity-card-body {
  display: flex; gap: calc(var(--spacing-unit) * 2.125); align-items: center;
  padding: calc(var(--spacing-unit) * 1.125) calc(var(--spacing-unit) * 1.5) calc(var(--spacing-unit) * 1.5);
}
.activity-statement { flex: 1; min-width: 0; }
.activity-streak-number { font-size: 4rem; font-weight: 820; line-height: .85; letter-spacing: -.02em; color: var(--streak-color); }
.activity-streak-label { font-size: .72rem; letter-spacing: .1em; text-transform: uppercase; color: var(--color-text-light); font-weight: 800; margin-top: 6px; }
.activity-sentence { font-size: 1.02rem; color: var(--color-text-secondary); font-weight: 500; margin: var(--spacing-lg) 0 0; max-width: 250px; line-height: 1.5; }
.activity-sentence b { color: var(--color-text); font-weight: 800; }
.activity-ministats { display: flex; gap: calc(var(--spacing-unit) * 1.625); margin-top: var(--spacing-xl); }
.activity-ministat-key { font-size: .62rem; text-transform: uppercase; letter-spacing: .05em; color: var(--color-text-light); font-weight: 700; }
.activity-ministat-value { font-size: 1.1rem; font-weight: 800; color: var(--color-text); margin-top: 2px; }

.activity-cal { width: 250px; flex-shrink: 0; }
.activity-weekdays { display: grid; grid-template-columns: repeat(7, 1fr); gap: 7px; margin-bottom: 7px; }
.activity-weekdays span { text-align: center; font-size: .6rem; color: var(--color-text-light); font-weight: 700; text-transform: uppercase; }
.activity-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 7px; }
.activity-cell {
  aspect-ratio: 1; border-radius: 7px;
  background: var(--activity-empty-bg);
  border: 1px solid var(--activity-empty-border);
  cursor: pointer; transition: var(--transition);
}
.activity-cell.state-day { background: var(--activity-day); border-color: transparent; }
.activity-cell.state-night { background: var(--activity-night); border-color: transparent; }
.activity-cell.state-both { background: var(--activity-both); border-color: transparent; }
.activity-cell.is-today { outline: 2px solid var(--activity-today-ring); outline-offset: 2px; }
.activity-cell.is-future { opacity: .5; cursor: default; }

.activity-legend { display: flex; gap: 13px; justify-content: center; margin-top: var(--spacing-md); font-size: .7rem; color: var(--color-text-light); font-weight: 700; }
.activity-legend span { display: inline-flex; align-items: center; gap: 5px; }
.activity-swatch { width: 11px; height: 11px; border-radius: 3px; display: inline-block; }
.activity-swatch.is-day { background: var(--activity-day); }
.activity-swatch.is-night { background: var(--activity-night); }
.activity-swatch.is-both { background: var(--activity-both); }

@media (hover: hover) {
  .activity-cell:not(.is-future):hover { transform: scale(1.08); box-shadow: var(--shadow-md); }
}
@media (max-width: 768px) {
  .activity-card-body { flex-direction: column; align-items: stretch; gap: var(--spacing-lg); }
  .activity-cal { width: 100%; }
}
```

- [ ] **Step 4: Commit**

```bash
git add app/views/drive_sessions/_activity_calendar.html.erb app/javascript/controllers/activity_calendar_controller.js app/assets/stylesheets/cards.css
git commit -m "feat(dashboard): streak-led activity card with day/night grid"
```

---

## Task 9: Recent drives — dashboard partials, destroy stream, index, CSS

**Files:**
- Create: `app/views/drive_sessions/_recent_drive_row.html.erb`
- Rewrite: `app/views/drive_sessions/_recent_drives_table.html.erb`
- Rewrite: `app/views/drive_sessions/destroy.turbo_stream.erb`
- Rewrite: `app/views/drive_sessions/index.html.erb`
- Modify: `app/assets/stylesheets/cards.css` (append recent-drive styles)

**Do not touch** `_session_row.html.erb` or `_table_header.html.erb` (shared with `#all`).

- [ ] **Step 1: Create `_recent_drive_row.html.erb`**

Reuses the existing `card-menu` controller/classes so the mobile bottom sheet works with zero new CSS/JS. No `dom_id` (avoids id collision with `#all` rows; the list is always replaced wholesale).

```erb
<div class="recent-drive-row" data-controller="drive-session card-menu">
  <div class="recent-drive-badge is-<%= session.is_night_drive ? "night" : "day" %>">
    <%= session.is_night_drive ? icon_moon(size: 18) : icon_sun(size: 18) %>
  </div>

  <div class="recent-drive-main">
    <div class="recent-drive-date"><%= local_time(session.started_at, format: "%B %d, %Y") %></div>
    <div class="recent-drive-sub"><%= session.notes.presence || "#{session.is_night_drive ? "Night" : "Day"} drive" %></div>
  </div>

  <div class="recent-drive-duration">
    <div class="recent-drive-duration-label">Duration</div>
    <div class="recent-drive-duration-value"><%= format_duration(session.duration_hours) %></div>
  </div>

  <div class="recent-drive-actions">
    <%= link_to "Edit", edit_drive_session_path(session), class: "action-link recent-drive-desktop-action" %>
    <%= button_to "Delete", drive_session_path(session),
                  method: :delete,
                  data: { turbo_confirm: "Are you sure?" },
                  class: "action-link-danger recent-drive-desktop-action",
                  form: { style: "display: inline;", data: { action: "submit->drive-session#handleDelete" } } %>

    <button type="button" class="card-menu-button recent-drive-kebab"
            data-card-menu-target="button" data-action="click->card-menu#toggle"
            aria-label="More options" aria-expanded="false">
      <%= icon_dots(size: 20, class: "card-menu-icon") %>
    </button>
    <div class="card-menu-backdrop" data-card-menu-target="backdrop" data-action="click->card-menu#handleBackdropClick"></div>
    <div class="card-menu hidden" data-card-menu-target="menu" data-action="click->card-menu#handleMenuItemClick">
      <div class="card-menu-options">
        <%= link_to edit_drive_session_path(session), class: "card-menu-item" do %><span>Edit</span><% end %>
        <%= button_to drive_session_path(session), method: :delete,
                      data: { turbo_confirm: "Are you sure?" },
                      class: "card-menu-item card-menu-item-danger",
                      form: { style: "display: inline;", data: { action: "submit->drive-session#handleDelete submit->card-menu#handleFormSubmit" } } do %>
          <span>Delete</span>
        <% end %>
        <button type="button" class="card-menu-cancel" data-action="click->card-menu#close">Cancel</button>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Rewrite `_recent_drives_table.html.erb`** (owns the `#recent-drives-table` id + empty state)

```erb
<div id="recent-drives-table" class="recent-drives-list">
  <% if recent_sessions.any? %>
    <%= render partial: "drive_sessions/recent_drive_row", collection: recent_sessions, as: :session %>
  <% else %>
    <p class="empty-state">No drives recorded yet. Start your first drive!</p>
  <% end %>
</div>
```

- [ ] **Step 3: Rewrite `destroy.turbo_stream.erb`** to replace the whole list with the new partial

```erb
<%= turbo_stream.replace "recent-drives-table" do %>
  <%= render "drive_sessions/recent_drives_table", recent_sessions: @recent_sessions %>
<% end %>
```

- [ ] **Step 4: Rewrite `index.html.erb`**

```erb
<% content_for :title, "Dashboard" %>

<%= turbo_stream_from Current.user %>

<%= render "shared/page_header", title: "Dashboard" %>

<div class="dashboard">
  <%= render "progress_summary",
             stats: @stats,
             activity_days: dashboard_activity_days(@activity_states, timezone: Current.user.timezone || "UTC") %>

  <section class="drive-history">
    <div class="drive-history-header">
      <h2 class="drive-history-title">Recent drives</h2>
      <% if Current.user.drive_sessions.completed.count > 3 %>
        <%= link_to "View all →", all_drive_sessions_path, class: "view-all-inline" %>
      <% end %>
    </div>
    <%= render "recent_drives_table", recent_sessions: @recent_sessions %>
  </section>
</div>
```

- [ ] **Step 5: Append recent-drive CSS to `cards.css`**

```css
/* ---- Recent drives ---- */
.drive-history-header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: var(--spacing-md); }
.drive-history-title { font-weight: 700; font-size: 1rem; margin: 0; }
.view-all-inline { font-size: .8rem; font-weight: 700; color: var(--color-primary); text-decoration: none; }

.recent-drives-list {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-lg);
  box-shadow: var(--shadow-sm);
  padding: var(--spacing-xs) var(--spacing-sm);
  font-feature-settings: "tnum" 1;
}
.recent-drive-row { display: flex; align-items: center; gap: 13px; padding: 11px 12px; border-radius: var(--border-radius-sm); }
.recent-drive-row + .recent-drive-row { border-top: 1px solid var(--color-border-light); }
@media (hover: hover) { .recent-drive-row:hover { background: var(--color-background); } }

.recent-drive-badge { width: 36px; height: 36px; border-radius: 10px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.recent-drive-badge.is-day { background: var(--recent-badge-day-bg); color: var(--recent-badge-day-fg); }
.recent-drive-badge.is-night { background: var(--recent-badge-night-bg); color: var(--recent-badge-night-fg); }

.recent-drive-main { flex: 1; min-width: 0; }
.recent-drive-date { font-weight: 700; font-size: .92rem; color: var(--color-text); }
.recent-drive-sub { font-size: .79rem; color: var(--color-text-light); margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.recent-drive-duration { text-align: right; flex-shrink: 0; }
.recent-drive-duration-label { font-size: .62rem; color: var(--color-text-light); text-transform: uppercase; letter-spacing: .04em; font-weight: 700; }
.recent-drive-duration-value { font-weight: 800; font-size: .98rem; color: var(--color-text); white-space: nowrap; }

.recent-drive-actions { display: flex; align-items: center; gap: var(--spacing-md); flex-shrink: 0; }
.recent-drive-desktop-action { }
.recent-drive-kebab { display: none; }

@media (max-width: 768px) {
  .recent-drive-desktop-action { display: none; }
  .recent-drive-kebab { display: flex; }        /* card-menu.css shows .card-menu-button on mobile too */
  .recent-drive-duration-label { display: none; }
}
```

Note: `.card-menu-button` already has `display: none` by default and `display: flex` at `max-width: 768px` in `card-menu.css`; the `.recent-drive-kebab` rules above mirror that so the kebab only shows on mobile. The `.card-menu` bottom sheet + backdrop styling comes entirely from `card-menu.css` — no new work.

- [ ] **Step 6: Manually verify the dashboard renders** (first full render of the new UI)

Use the `/run` skill or: `bin/dev`, sign in, visit `/`. Confirm hero, activity card, and recent-drive rows render without errors. Check the Rails log for missing-partial or `NoMethodError`.

- [ ] **Step 7: Commit**

```bash
git add app/views/drive_sessions/_recent_drive_row.html.erb app/views/drive_sessions/_recent_drives_table.html.erb app/views/drive_sessions/destroy.turbo_stream.erb app/views/drive_sessions/index.html.erb app/assets/stylesheets/cards.css
git commit -m "feat(dashboard): icon-led recent drives with reused mobile bottom sheet"
```

---

## Task 10: Update model broadcasts for the new dashboard

**Files:**
- Modify: `app/models/drive_session.rb` (`broadcast_create`, `broadcast_update`, `broadcast_progress_summary`)
- Test: `test/models/drive_session_test.rb` (broadcast smoke test), plus manual real-time check

The old in-progress **stat card** (`#in-progress-drive`) is gone; the in-progress **banner** (`#in-progress-banner-container`) and FAB (`#fab-new-drive-wrapper`) remain and are already updated by `broadcast_progress_summary`. `broadcast_progress_summary` must now pass the new stats + activity days into `_progress_summary`.

- [ ] **Step 1: Update `broadcast_progress_summary`**

Replace the `broadcast_replace_to ... target: "progress-summary"` call's locals so it renders the new partial signature. Full method:

```ruby
def broadcast_progress_summary
  user.association(:drive_sessions).reset
  relation = user.drive_sessions
  tz = user.timezone || "UTC"

  statistics = DriveSession.statistics_for(relation, timezone: tz)
  activity_days = ApplicationController.helpers.dashboard_activity_days(
    relation.activity_day_states(timezone: tz), timezone: tz
  )

  broadcast_replace_to user,
                       target: "progress-summary",
                       html: ApplicationController.render(
                         partial: "drive_sessions/progress_summary",
                         locals: { stats: statistics, activity_days: activity_days }
                       )

  broadcast_update_to user,
                      target: "in-progress-banner-container",
                      html: ApplicationController.render(
                        partial: "shared/in_progress_banner",
                        locals: { in_progress: statistics[:in_progress] }
                      )

  broadcast_update_to user,
                      target: "fab-new-drive-wrapper",
                      html: ApplicationController.render(
                        partial: "shared/fab_new_drive",
                        locals: { in_progress: statistics[:in_progress] }
                      )
end
```

- [ ] **Step 2: Remove the `#in-progress-drive` target from `broadcast_create`**

Replace `broadcast_create` with:

```ruby
def broadcast_create
  if completed?
    broadcast_recent_drives_table
    broadcast_append_to user, target: "sessions-tbody", html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
  end
  broadcast_progress_summary
end
```

(The in-progress case is now fully handled by `broadcast_progress_summary` updating the banner + FAB.)

- [ ] **Step 3: Remove the `#in-progress-drive` remove-call from `broadcast_update`**

In `broadcast_update`, delete the line `broadcast_remove_to user, target: "in-progress-drive"` (inside the `was_in_progress` branch). Keep the `sessions-tbody` append and the per-row `dom_id` replace (both belong to `#all`). The method becomes:

```ruby
def broadcast_update
  if completed?
    was_in_progress = saved_change_to_ended_at? && ended_at.present? && ended_at_before_last_save.nil?

    if was_in_progress
      broadcast_append_to user, target: "sessions-tbody", html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
    else
      broadcast_replace_to user, target: ActionView::RecordIdentifier.dom_id(self), html: ApplicationController.render(partial: "drive_sessions/session_row", locals: { session: self })
    end

    broadcast_recent_drives_table
  end
  broadcast_progress_summary
end
```

- [ ] **Step 4: Confirm `broadcast_recent_drives_table` still renders the dashboard partial**

It already does `broadcast_replace_to target: "recent-drives-table", html: render(partial: "drive_sessions/recent_drives_table", locals: { recent_sessions: ... })`. The rewritten partial has the matching `#recent-drives-table` root id, so `replace_to` works unchanged. No edit needed — just verify.

- [ ] **Step 5: Broadcast smoke test**

Add to `test/models/drive_session_test.rb` (guards against render errors in the broadcast path):

```ruby
test "creating and completing a drive broadcasts without error" do
  @user.update!(timezone: "America/Chicago")
  assert_nothing_raised do
    d = @user.drive_sessions.create!(driver_name: "D", started_at: 2.hours.ago)
    d.update!(ended_at: Time.current)
    d.destroy!
  end
end
```

Run: `bin/rails test test/models/drive_session_test.rb -n "/broadcasts without error/"`
Expected: PASS.

- [ ] **Step 6: Manual real-time verification**

With `bin/dev` running and the dashboard open in two tabs: start a drive, complete it, delete it. Confirm the hero numbers, activity grid, recent-drive list, and in-progress banner/FAB all update live in both tabs with no console/log errors.

- [ ] **Step 7: Commit**

```bash
git add app/models/drive_session.rb test/models/drive_session_test.rb
git commit -m "feat(dashboard): update broadcasts for redesigned dashboard, drop in-progress stat card"
```

---

## Task 11: Remove dead code and final verification

**Files:**
- Delete: `app/views/drive_sessions/_stat_card.html.erb`, `app/views/drive_sessions/_in_progress_drive.html.erb`
- Modify: `app/helpers/drive_session_helper.rb` (remove `circular_progress` and `activity_calendar_data`)
- Modify: `test/helpers/drive_session_helper_test.rb` (delete the tests for the removed helpers)
- Modify: `app/assets/stylesheets/cards.css` (remove old `.stat-card`, `.progress-summary`, old `.activity-*` grid rules that are now unused)

- [ ] **Step 1: Confirm the old partials/helpers are unreferenced in app code**

Run:
```bash
grep -rn "stat_card\|in_progress_drive\|circular_progress\|activity_calendar_data" app/
```
Expected: within `app/`, the only remaining hits are the definitions themselves — `_stat_card.html.erb`, `_in_progress_drive.html.erb`, and the `circular_progress` / `activity_calendar_data` method defs in `drive_session_helper.rb`. There should be **no** `render`/call-site references left (Tasks 7–10 removed them). If any app call site remains, stop and resolve it before deleting.

Then check the test references (there ARE many — this is expected, not a blocker):
```bash
grep -rn "circular_progress\|activity_calendar_data" test/
```
Expected: hits only in `test/helpers/drive_session_helper_test.rb` (≈9 `circular_progress` tests and ≈15 `activity_calendar_data` tests). These tests must be deleted along with the helpers in Step 2.

Note: `activity_by_date` (model) may also now be unused by app code, but it is harmless and out of scope — **leave it and its tests alone.**

- [ ] **Step 2: Delete unused partials, helpers, and their tests**

```bash
git rm app/views/drive_sessions/_stat_card.html.erb app/views/drive_sessions/_in_progress_drive.html.erb
```
- In `app/helpers/drive_session_helper.rb`, remove the `circular_progress` and `activity_calendar_data` methods (keep `format_duration`).
- In `test/helpers/drive_session_helper_test.rb`, delete the `# circular_progress tests` block (the ≈9 tests, currently lines ~196–264) and the `# activity_calendar_data tests` block (the ≈15 tests, currently lines ~66–194). Keep all `format_duration` tests and the new `dashboard_activity_days` test added in Task 6.
- Remove the now-unused old CSS blocks in `cards.css` (`.stat-card*`, `.progress-summary`, the old `.activity-calendar*`/`.activity-day` GitHub-grid rules, `.in-progress-drive` stat-card rules). **Keep all the new redesign blocks** — `.dashboard-summary`, `.dash-hero*`, `.activity-card`, `.activity-cal`, `.activity-grid`, `.activity-cell*`, `.activity-weekdays`, `.activity-legend`, `.activity-swatch*`, `.recent-drive*` — plus the still-used `.dashboard`, `.drive-history`, `.empty-state`, and `.tooltip-trigger`. The new component was deliberately named `.activity-cal` (not `.activity-calendar`) so deleting the old `.activity-calendar*` rules cannot touch it. Grep each class before deleting its block.

- [ ] **Step 3: Run the full test suite**

Run: `bin/rails test`
Expected: PASS (all green). Fix any fallout (e.g. a controller/system test asserting old markup — update it to the new structure).

- [ ] **Step 4: Run RuboCop**

Run: `bin/rubocop`
Expected: no new offenses. `bin/rubocop -a` for autocorrectable ones.

- [ ] **Step 5: Manual verification checklist (light, dark, mobile)**

With `bin/dev` running, verify:
- Light mode: hero gradient + sunset horizon, chips legible, activity grid amber/indigo/split correct, today ring visible, recent rows with badges.
- Dark mode (OS set to dark, or toggle if the app has one): hero deepens with hairline border, activity empty cells are slate, day/night use the lighter shades, today ring lightens, recent badges use dark tokens.
- Mobile width (≤768px): hero number scales, finish stat drops below, chips 2×2; activity statement stacks above a full-width grid; recent rows compress and the ⋮ opens the bottom action sheet (Edit/Delete/Cancel).
- Edge cases: a brand-new user (0 drives) shows `0.0 of 50`, "Keep driving", "0 day streak", "0 of the last 21 days", empty grid, and the recent-drives empty state.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(dashboard): remove dead stat-card/circular-progress code after redesign"
```

---

## Done

At this point the dashboard redesign is complete: derived stats are computed and tested, the three components render in light/dark and mobile, real-time broadcasts are preserved, the All-drives page is untouched, and dead code is removed. Open a PR from `redesign-dashboard`.
