# AGENTS.md

Guidance for AI coding agents working in this repository. This file is the
**single source of truth** and is shared across tools (Claude Code, Codex,
Cursor, OpenCode). `CLAUDE.md` intentionally just points here — edit this file,
not a per-tool copy.

## Project Overview

Drive50 is a Rails 8.1 application for tracking supervised driving hours toward a
driver's license. A learner logs 50 total hours, of which 10 must be night hours.
The app is a mobile-first PWA with real-time updates via Turbo Streams and Action
Cable, progress statistics (streaks, weekly pace, projected finish), CSV export,
and web push reminders for in-progress drives.

## Development Commands

### Setup
```bash
bin/setup                    # Install dependencies, prepare DB, start server
bin/setup --reset            # Reset database before starting
bin/setup --skip-server      # Setup without starting server
```

### Running the server
```bash
bin/dev                      # Start Rails server (default port 3000)
```

### Database
```bash
bin/rails db:prepare         # Create and set up database
bin/rails db:migrate         # Run pending migrations
bin/rails db:reset           # Drop, create, and migrate
```

### Testing
```bash
bin/rails test               # Run all tests
bin/rails test:system        # System tests only
bin/rails test test/models/user_test.rb      # A single file
bin/rails test test/models/user_test.rb:12   # A single test at line 12
```

### Code quality (all run in CI on every PR; `main` requires them green)
```bash
bin/rubocop                  # RuboCop (Omakase Ruby styling); -a to autocorrect
bin/brakeman --no-pager      # Rails security scanner
bin/bundler-audit            # Vulnerable gem check
bin/importmap audit          # JS dependency vulnerabilities
```

### Console
```bash
bin/rails console            # Rails console
bin/rails console --sandbox  # Rolls back all changes on exit
```

## Architecture

### Data model

- **`User`** — `has_secure_password`; owns `sessions`, `drive_sessions`, and
  `push_subscriptions`. Stores `first_name`, `last_name`, `email_address`
  (normalized lowercase, unique), `timezone`, and optional `latitude`/`longitude`.
  `full_name` is the displayed driver name.
- **`Session`** — authentication session with `ip_address` and `user_agent`.
- **`DriveSession`** — one driving session. Columns: `started_at`, `ended_at`,
  `duration_minutes`, `is_night_drive`, `notes`, `user_id`. State is derived, not
  stored: **in-progress** (no `ended_at`) or **completed** (has `ended_at`).
  `duration_minutes` and `is_night_drive` are computed in `before_save` callbacks.
- **`PushSubscription`** — a browser Web Push endpoint (`endpoint`, `p256dh_key`,
  `auth_key`, `user_agent`) belonging to a user.

**Key constants** (`DriveSession`):
- `HOURS_NEEDED = 50`, `NIGHT_HOURS_NEEDED = 10`
- `ACTIVITY_CALENDAR_DAYS = 28`, `REMINDER_DELAY = 45.minutes`

**Scopes:** `.completed` / `.in_progress`, `.night_drives`, `.ordered` (reverse
chronological), `.with_user` (preloads the owner to avoid N+1 in views/CSV).

### Night-drive detection

Night classification is **sunrise/sunset based, not a fixed clock window**.
`DriveSession#determine_night_drive` uses the `RubySunrise` gem
(`SolarEventCalculator`) to compute civil sunrise/sunset for the drive's date at
the user's coordinates — falling back to representative coordinates for the user's
timezone via `TimezoneCoordinates` when lat/lon are absent. A drive counts as a
night drive if **either** its start or end falls before civil sunrise or after
civil sunset (local time). See the comment in `night_time?` for the UTC-offset
handling that avoids a calendar-date bug across the Americas / DST boundaries.

### Statistics

`DriveSessionStatistics` (concern on `DriveSession`) computes everything the
dashboard shows via `statistics_for(relation, timezone:)`: total/day/night hours,
hours remaining, this/last week hours, active-day count, current and best
streaks, weekly pace, and a human-readable `projected_finish` label. All
date math is done in the user's timezone (Sunday-aligned weeks).

### Real-time updates (Turbo Streams + Action Cable)

1. **Broadcasting** — `DriveSession` callbacks broadcast per-user:
   `after_create_commit :broadcast_create`, `after_update_commit :broadcast_update`,
   `after_destroy_commit :broadcast_destroy`. All broadcasts are scoped with
   `broadcast_*_to user`.
2. **Channel** — `ApplicationCable::DriveSessionsChannel` streams to the
   authenticated user with `stream_for current_user`. `Connection` identifies the
   user from the signed `session_id` cookie.
3. **Update targets** (must match DOM IDs in views):
   - `progress-summary` — totals, night hours, remaining, activity calendar
   - `recent-drives-table` — most recent completed drives
   - `sessions-list` — appended/replaced per-row on the all-drives page
     (rows are targeted by their `dom_id`)
   - `in-progress-banner-container` and `fab-new-drive-wrapper` — reflect whether
     a drive is currently in progress
4. **State transitions** — completing a drive (in-progress → completed) appends a
   new row rather than replacing one; statistics are always recomputed after any
   change.

### Background jobs & push notifications

- **Solid stack** — `solid_queue` (jobs), `solid_cache`, `solid_cable`. Recurring
  maintenance is configured in `config/recurring.yml`.
- **`DriveSessionReminderJob`** — scheduled (`REMINDER_DELAY`) when a drive starts
  *and* the user has push subscriptions; reminds them a drive is still running.
- **`WebPushService`** / **`WebPushJob`** — deliver Web Push notifications via the
  `web-push` gem to the user's `PushSubscription` endpoints.

### Authentication

Custom session-based auth (not Devise), in the `Authentication` concern:
- `before_action :require_authentication` by default; opt out per-controller with
  `allow_unauthenticated_access`.
- Sessions persisted in the DB with IP and user agent; the session id is stored in
  a signed permanent cookie.
- Password reset via signed tokens (`User#password_reset_token`, expires in 1 hour).
- Use `Current.session` and `Current.user` for request context — not instance
  variables. `Current.user` delegates through `Current.session`.

### Frontend

**Hotwire stack:** Turbo Rails (SPA-like nav + real-time updates), Stimulus, and
ImportMaps (no build step). CSS is plain, componentized files under
`app/assets/stylesheets/` served by Propshaft. `local_time` renders UTC times in
the user's browser timezone.

**Stimulus controllers** (`app/javascript/controllers/`): `timer`,
`drive_session`, `drive_modal`, `card_menu`, `menu`, `toast`, `export`,
`activity_calendar`, `location`, `push_notifications`, `timezone`,
`timezone_detector`.

### PWA

Installable PWA: `app/views/pwa/manifest.json.erb` and `service-worker.js.erb`,
served through Rails' built-in `rails/pwa` controller (routed at `/manifest.json`
and `/service-worker.js`). Timezone and geolocation are detected client-side and
posted back (`timezones#update`, `push_subscriptions`).

### Pagination

Pagy v43, offset pagination on the all-drives page:
```ruby
@pagy, @sessions = pagy(:offset, collection, limit: 20)
```
"Load More" navigates the `sessions-pagination` Turbo frame; the controller
renders `_pagination_frame.turbo_stream.erb` to append the next page.

## File Organization

- `app/models/` — ActiveRecord models + `concerns/` (statistics, timezone coords)
- `app/controllers/` — `DriveSessionsController` is the main feature
- `app/views/drive_sessions/` — main UI with Turbo Frame/Stream partials
- `app/channels/` — Action Cable connection and channel
- `app/jobs/` — reminder and web-push jobs
- `app/services/` — `WebPushService`
- `app/javascript/controllers/` — Stimulus controllers
- `test/` — Minitest (models, controllers, jobs, services, system)
- `db/migrate/` — migrations

## Important Patterns

### Turbo Streams in model callbacks
- Render partials from the model with `ApplicationController.render(partial: ...)`
  (and `ApplicationController.helpers` for view helpers).
- Target IDs must match DOM elements in the views (see the list above).
- Distinguish create vs. in-progress → completed transitions (append vs. replace).
- Recompute statistics after every change; reset the `drive_sessions` association
  before recomputing so freshly-committed rows are included.

### Current context
Use `Current.user` / `Current.session`, never per-request instance variables for
the signed-in user.

### Preloading
Any collection whose rows read `user.full_name` (views, CSV export) should use the
`.with_user` scope to avoid N+1 queries.

## Environment

- Ruby: see `.ruby-version` (currently 3.4.7)
- Rails: 8.1.x
- Database: SQLite3 (with the Solid adapters for cache/queue/cable)
- Deployment: Kamal (Docker-based), fronted by Thruster
