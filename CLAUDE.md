# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Drive50 is a Rails 8.1 application for tracking supervised driving hours toward a driver's license. The app tracks 50 total hours (including 10 night hours) and uses real-time updates via Turbo Streams and Action Cable.

## Development Commands

### Setup
```bash
bin/setup                    # Initial setup: installs dependencies, prepares DB, starts server
bin/setup --reset            # Reset database before starting
bin/setup --skip-server      # Setup without starting server
```

### Running the Server
```bash
bin/dev                      # Start Rails server (default port 3000)
bin/rails server             # Alternative way to start server
```

### Database
```bash
bin/rails db:prepare         # Create and setup database
bin/rails db:migrate         # Run pending migrations
bin/rails db:reset           # Drop, create, and migrate database
bin/rails db:schema:load     # Load schema without running migrations
```

### Testing
```bash
bin/rails test               # Run all tests
bin/rails test:system        # Run system tests only
bin/rails test test/models/user_test.rb              # Run specific test file
bin/rails test test/models/user_test.rb:12           # Run specific test at line 12
```

### Code Quality
```bash
bin/rubocop                  # Run RuboCop linter (uses Omakase Ruby styling)
bin/rubocop -a               # Auto-correct offenses
bin/brakeman                 # Security vulnerability scanner
bin/bundle-audit             # Check for vulnerable gem versions
```

### Console
```bash
bin/rails console            # Start Rails console
bin/rails console --sandbox  # Console that rolls back all changes on exit
```

## Architecture

### Data Model

**Core entities:**
- `User` - Has secure password, owns sessions and drive sessions
- `Session` - Authentication sessions with IP and user agent tracking
- `DriveSession` - Individual driving sessions with duration tracking
  - Tracks: `driver_name`, `started_at`, `ended_at`, `duration_minutes`, `is_night_drive`, `notes`
  - Belongs to User
  - State: in-progress (no `ended_at`) or completed (has `ended_at`)

**Key constants** (`DriveSession` model):
- `HOURS_NEEDED = 50` - Total hours required
- `NIGHT_HOURS_NEEDED = 10` - Night hours required (8pm-6am)

### Real-Time Updates Architecture

The app uses a sophisticated real-time update system combining Turbo Streams and Action Cable:

1. **Broadcasting Layer** - `DriveSession` model has callbacks that broadcast changes:
   - `after_create_commit :broadcast_create`
   - `after_update_commit :broadcast_update`
   - `after_destroy_commit :broadcast_destroy`
   - Broadcasts are scoped per-user via `broadcast_*_to user`

2. **Action Cable Channel** - `DriveSessionsChannel` streams updates to authenticated users:
   - Uses `stream_for current_user` for user-specific broadcasts

3. **Update Targets** - Multiple DOM elements update independently:
   - `#in-progress-drive` - Current active drive with live timer
   - `#recent-drives-table` - Top 3 recent completed drives
   - `#sessions-tbody` - All drives table (on `/drive_sessions/all` page)
   - `#progress-summary` - Total hours, night hours, hours remaining

4. **State Transitions** - Special handling when drive completes:
   - Removes from in-progress section
   - Adds to completed drives table
   - Updates recent drives if in top 3
   - Recalculates all statistics

### Authentication

Uses custom session-based authentication (not Devise):
- `Authentication` concern handles session management
- Sessions stored in database with IP and user agent
- Signed permanent cookies for session ID
- Password reset via signed tokens (expires in 1 hour)
- `Current.session` and `Current.user` for request context

### Frontend Architecture

**Hotwire stack:**
- Turbo Rails for SPA-like navigation and real-time updates
- Stimulus controllers for interactive behaviors
- ImportMaps for JavaScript modules (no build step)

**Key Stimulus controllers:**
- `timer_controller.js` - Live elapsed time for in-progress drives
- `drive_session_controller.js` - Drive session form interactions
- `infinite_scroll_controller.js` - Pagination on all drives page
- `toast_controller.js` - Flash message notifications

**LocalTime gem** - Converts UTC times to user's local timezone in browser

### Pagination

Uses Pagy v43 with offset pagination:
```ruby
@pagy, @sessions = pagy(:offset, collection, limit: 20)
```
Combined with infinite scroll for seamless loading.

## File Organization

- `app/models/` - ActiveRecord models with business logic
- `app/controllers/` - Controllers (note: `DriveSessionsController` is the main feature)
- `app/views/drive_sessions/` - Main UI templates with Turbo Frame/Stream partials
- `app/channels/` - Action Cable channels for WebSocket connections
- `app/javascript/controllers/` - Stimulus controllers
- `test/` - Minitest tests (models, controllers, system tests)
- `db/migrate/` - Database migrations

## Important Patterns

### Turbo Streams in Model Callbacks

When modifying `DriveSession` broadcasts, remember:
- Use `ApplicationController.render(partial: ...)` to render partials from models
- Target IDs must match DOM elements in views
- Handle both create and update-to-completed transitions differently
- Always recalculate statistics after changes

### Current Context

Use `Current.user` and `Current.session` instead of instance variables for current user/session throughout the request lifecycle.

### Scopes

`DriveSession` has useful scopes:
- `.completed` / `.in_progress` - Filter by state
- `.night_drives` - Filter night drives only
- `.ordered` - Reverse chronological order

## Environment

- Ruby version: See `.ruby-version` (currently 3.3.6)
- Rails: 8.1.1
- Database: SQLite3
- Deployment: Kamal (Docker-based)
