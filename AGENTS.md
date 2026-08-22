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
  `full_name` is the displayed driver name. `hours_goal`/`night_hours_goal`
  default to 50/10 (the DB column defaults) but are per-user and editable at
  signup and in Settings; `night_hours_goal` can't exceed `hours_goal`. These
  are what `statistics_for` measures progress against — see Statistics below.
- **`Session`** — authentication session with `ip_address` and `user_agent`.
- **`DriveSession`** — one driving session. Columns: `started_at`, `ended_at`,
  `duration_minutes`, `night_minutes`, `notes`, `user_id`. State
  is derived, not stored: **in-progress** (no `ended_at`) or **completed** (has
  `ended_at`). `duration_minutes` and `night_minutes` are both computed in
  `before_save` callbacks, from the same start/end pair; `night_minutes` is what
  statistics sum. `#kind` names the drive `:day`, `:night` or `:mixed`.
- **`PushSubscription`** — a browser Web Push endpoint (`endpoint`, `p256dh_key`,
  `auth_key`, `user_agent`) belonging to a user.

**Key constants** (`DriveSession`):
- `HOURS_NEEDED = 50` — the default shown on the marketing page and the fallback
  for `projected_finish` when called directly on a relation without a goal.
  A signed-in user's actual goal is `User#hours_goal`/`night_hours_goal` (the
  migration hardcodes the same 50/10 as the column defaults, deliberately not
  referencing this constant — see its comment). `statistics_for` always passes the
  user's own goal explicitly.
- `REMINDER_DELAY = 45.minutes`, `MAX_DRIVE_DURATION = 7.days` (a validation ceiling —
  `night_seconds` walks one date per day spanned, so an unbounded span is unbounded CPU)

**Scopes:** `.completed` / `.in_progress`, `.ordered` (reverse chronological),
`.with_user` (preloads the owner to avoid N+1 in views/CSV), and the drive log's
filters `.with_day` / `.with_night` / `.matching_kind(filter)`. The first two are
the SQL counterparts of `any_day?` / `any_night?`, so a drive that crossed sunset
matches **both** — it credited hours to both dashboard tiles, which is where the
filters are reached from. `KIND_FILTERS` lists the values the controller accepts.

**Activity grid:** `DriveSession.activity_days(timezone:)` groups completed drives
into `{ Date => [drives] }` across exactly the 21 cells the grid renders, and
`ActivityDay.grid_for` expands that into the cells themselves — one `ActivityDay`
per day, which owns its `state`, `aria_label` and `as_json` payload. One query feeds
both the grid and the day-summary modal; don't add a second pass over the same
window. Past cells render as `<button>` and open the modal from `data-day-summary`
JSON, the same no-round-trip approach as the drive-detail modal; a future cell stays
an inert `<div>` unless a drive was logged against it.

### Night-drive detection

Night classification is **sunrise/sunset based, not a fixed clock window**, and a
drive is credited **minute by minute rather than all-or-nothing**.
`DriveSession#determine_night_drive` uses the `RubySunrise` gem
(`SolarEventCalculator`) to compute official sunrise/sunset for the drive's date at
the user's coordinates — falling back to representative coordinates for the user's
timezone via `TimezoneCoordinates` when lat/lon are absent.

`night_seconds` cuts the drive at every solar event it spans and classifies each
piece by its midpoint, so a drive that starts in daylight and ends after dark is
split between the day and night totals instead of tipping wholly into one. That
also makes overnight and multi-day drives correct without special cases.

Things to preserve when touching this code — each has a regression test, and each
was a real bug:
- **Official, not civil, sunset.** Civil dusk is ~30 minutes later; using it left
  post-sunset driving credited as day hours.
- **`local_instant` rebuilds each event from its UTC time-of-day**, reading the
  offset at local *noon*. RubySunrise stamps the event onto the date it was handed,
  so its raw instant can land on the wrong UTC day (in the Americas sunset is after
  00:00 UTC); reading the offset at midnight breaks both DST transition days.
- **`night_time?` classifies the wrapped window** rather than discarding it. Near
  the Arctic Circle the sun can set just after local midnight, putting sunset
  *before* sunrise on the same date (Fairbanks: 46 days a year); night is then the
  interval between them. Bailing out instead credited real night driving as day.
- **`night_minutes` truncates and is capped at `duration_minutes`.** Duration floors,
  so rounding here put night a minute over and made `day_hours` negative.
- **Both derived columns share one callback guard.** Editing only `started_at` used
  to recompute night against a stale duration.

`DriveSession#kind` is the one place a drive is classified `:day`, `:night` or
`:mixed`. `drive_kind_label` is the one place that wording lives and
`drive_kind_icon` the one place the glyph does — the drive row's badge and
screen-reader label and the detail modal's heading all render from them, and they
travel to the client as `data-drive-kind` / `data-drive-kind-label`. Don't
re-derive any of them at a call site; the wording had already drifted once ("Day
and night drive" against "Day & night drive"), and the badge used to fall back to
the night icon for a mixed drive, making it indistinguishable from a pure night
one.

Known gap: when RubySunrise returns nil for both events it is impossible to tell
midnight sun from polar night, and the code assumes daylight. Above the Arctic Circle
that zeroes night credit for roughly two months of continuous darkness a year.

Coordinates and UTC offset must agree — `TimezoneCoordinates` places unmapped zones
on the meridian matching their offset for exactly this reason.

### Statistics

`DriveSessionStatistics` (concern on `DriveSession`) computes everything the
dashboard shows via `statistics_for(user, timezone:)`: total/day/night hours, hours
remaining, this/last week hours, active-day count, current and best streaks, weekly
pace, and a human-readable `projected_finish` label. `hours_needed` and
`night_hours_needed` (and `projected_finish`) measure against the user's own
`hours_goal`/`night_hours_goal`. All date math is done in the user's timezone
(Sunday-aligned weeks).

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
   - `sessions-list-{all,day,night}` — prepended per-row on the all-drives page,
     which renders the list for its active filter only (and renders it even when
     empty, so a drive completed elsewhere has somewhere to land). Replaces are
     targeted by the row's `dom_id`
   - `in-progress-banner-container` and `fab-new-drive-wrapper` — reflect whether
     a drive is currently in progress
4. **State transitions** — completing a drive (in-progress → completed) inserts a
   new row rather than replacing one; statistics are always recomputed after any
   change. The insert goes through `broadcast_drive_row`, which **prepends** —
   the log is newest-first — and skips a drive that isn't the newest, since a
   backdated one belongs mid-list where neither prepend nor append can put it.
   A broadcast can't know which kind filter the page is on, so
   `matching_kind_filters` addresses every list the drive belongs in and only the
   one on the viewer's page finds a target.

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
`drive_session`, `drive_modal`, `day_modal`, `card_menu`, `menu`, `toast`, `export`,
`location`, `push_notifications`, `timezone`,
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
