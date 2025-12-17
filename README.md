# Drive50

A Rails 8.1 application for tracking supervised driving hours toward a driver's license. The app tracks 50 total hours (including 10 night hours) and provides real-time updates via Turbo Streams and Action Cable.

## Features

- Track driving sessions with start/end times
- Automatic night drive detection (8pm-6am in user's timezone)
- Real-time progress tracking with live updates
- Timezone-aware time handling
- Export driving log to CSV
- Mobile-responsive design with PWA support

## Prerequisites

- **Ruby 3.4.7** (see `.ruby-version`)
- **Bundler** (for managing Ruby gems)
- **SQLite3** (database)
- **Foreman** (for running multiple processes in development - `gem install foreman`)
- Node.js is not required (uses ImportMaps, no build step)

## Development Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd drive50
```

### 2. Install dependencies

```bash
bundle install
```

### 3. Set up the database

```bash
bin/rails db:prepare
```

Or to reset and seed with sample data:

```bash
bin/rails db:reset
bin/rails db:seed
```

### 4. Start the development server

```bash
bin/dev
```

This will start:
- Rails server on http://localhost:3000
- Solid Queue jobs processor (for background jobs)

**Alternative setup:**

```bash
bin/setup              # Full setup (installs deps, prepares DB, starts server)
bin/setup --reset      # Reset database before starting
bin/setup --skip-server # Setup without starting server
```

## Running Tests

```bash
# Run all tests
bin/rails test

# Run only system tests
bin/rails test:system

# Run specific test file
bin/rails test test/models/user_test.rb

# Run specific test at a line number
bin/rails test test/models/user_test.rb:12
```

## Code Quality

```bash
# Run RuboCop linter (Omakase Ruby styling)
bin/rubocop

# Auto-correct RuboCop offenses
bin/rubocop -a

# Security vulnerability scanner
bin/brakeman

# Check for vulnerable gem versions
bin/bundler-audit
```

## Database Management

```bash
# Create and setup database
bin/rails db:prepare

# Run pending migrations
bin/rails db:migrate

# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# Load schema without running migrations
bin/rails db:schema:load
```

## Development Workflow

### Console

```bash
# Start Rails console
bin/rails console

# Console that rolls back all changes on exit
bin/rails console --sandbox
```

### Background Jobs

The app uses Solid Queue for background jobs (e.g., sending emails with `deliver_later`). The jobs processor is automatically started with `bin/dev` via `Procfile.dev`.

**Important**: Solid Queue requires its database tables to be set up. If you see errors about missing `solid_queue_*` tables, run:

```bash
bin/rails runner "load 'db/queue_schema.rb'"
```

To run jobs manually:

```bash
bin/jobs
```

## Important Configuration

### Timezone Handling

The app automatically detects and stores each user's timezone:

- **Detection**: Browser timezone is detected via JavaScript (Stimulus `timezone_controller`) and sent with forms
- **Storage**: User timezone is stored in the `users.timezone` column (defaults to "UTC")
- **Display**: Times are displayed in user's timezone using the `local_time` gem
- **Forms**: Datetime inputs are interpreted in the user's timezone (via `Time.zone` in ApplicationController) and converted to UTC for storage
- **Night Drive**: Calculated based on start/end times in the user's timezone (8pm-6am)

**Note**: The timezone is automatically saved to the user's profile when detected, so it persists across sessions.

### Email Configuration

In development, emails use the `:test` delivery method (stored in `ActionMailer::Base.deliveries`).

For production, configure Resend SMTP credentials:

```bash
bin/rails credentials:edit
```

Add:
```yaml
resend:
  api_key: your-resend-api-key

mail:
  from: noreply@yourdomain.com
  host: yourdomain.com
```

See `docs/credentials-setup.md` for more details.

## Project Structure

### Key Models

- `User` - User accounts with timezone support
- `DriveSession` - Individual driving sessions
- `Session` - Authentication sessions

### Key Controllers

- `DriveSessionsController` - Main feature (CRUD for drive sessions)
- `SessionsController` - Authentication
- `RegistrationsController` - User signup
- `PasswordsController` - Password reset

### Real-Time Updates

The app uses Turbo Streams and Action Cable for real-time updates:

- Drive sessions broadcast updates when created/updated/destroyed
- Updates are scoped per-user
- Multiple DOM targets update independently (in-progress drive, recent drives, all drives table, progress summary)

### Frontend

- **Hotwire**: Turbo Rails + Stimulus
- **No build step**: Uses ImportMaps for JavaScript
- **LocalTime gem**: Converts UTC times to user's local timezone in the browser

## Deployment

The app is configured for deployment with Kamal (Docker-based). See `config/deploy.yml` for deployment configuration.

## License

[Add your license here]

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests: `bin/rails test`
4. Run linters: `bin/rubocop`
5. Submit a pull request
