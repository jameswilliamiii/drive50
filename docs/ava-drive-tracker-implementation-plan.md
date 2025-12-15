# Ava Drive Tracker - Implementation Plan

## Overview
A simple Rails 8.1 application to track driving practice hours for Illinois learner's permit holders. Follows 37signals Fizzy patterns: vanilla Rails, Hotwire/Turbo, importmaps, standard CSS, Solid Queue/Cache, and encrypted credentials.

### Illinois Requirements
- **Total Hours**: 50 hours minimum practice
- **Night Hours**: 10 hours minimum (between sunset and sunrise)
- No specific requirements for weather, road types, or other conditions

---

## Prerequisites
Assumptions:
- Fresh Rails 8.1 app generated with: `rails new ava_drive_tracker`
- SQLite3 database (default)
- Ruby version 3.4.7
- All following commands run from app root

---

## Phase 1: Database Schema & Models

### Step 1.1: Generate Drive Session Model
```bash
bin/rails generate model DriveSession \
  started_at:datetime \
  ended_at:datetime \
  duration_minutes:integer \
  is_night_drive:boolean \
  notes:text \
  supervisor_name:string \
  driver_name:string
```

### Step 1.2: Edit Migration
Edit `db/migrate/XXXXXX_create_drive_sessions.rb`:

```ruby
class CreateDriveSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :drive_sessions do |t|
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_minutes
      t.boolean :is_night_drive, default: false, null: false
      t.text :notes
      t.string :supervisor_name
      t.string :driver_name, null: false

      t.timestamps
    end

    add_index :drive_sessions, :started_at
    add_index :drive_sessions, :ended_at
  end
end
```

### Step 1.3: Run Migration
```bash
bin/rails db:migrate
```

### Step 1.4: Define Model
Edit `app/models/drive_session.rb`:

```ruby
class DriveSession < ApplicationRecord
  # Validations
  validates :driver_name, presence: true
  validates :started_at, presence: true
  validate :ended_at_after_started_at, if: -> { ended_at.present? }

  # Scopes
  scope :completed, -> { where.not(ended_at: nil) }
  scope :in_progress, -> { where(ended_at: nil) }
  scope :night_drives, -> { where(is_night_drive: true) }
  scope :ordered, -> { order(started_at: :desc) }

  # Callbacks
  before_save :calculate_duration, if: -> { ended_at.present? && ended_at_changed? }
  before_save :determine_night_drive, if: -> { started_at_changed? || ended_at_changed? }

  # Class methods
  def self.total_hours
    completed.sum(:duration_minutes) / 60.0
  end

  def self.night_hours
    night_drives.completed.sum(:duration_minutes) / 60.0
  end

  def self.hours_needed
    [50 - total_hours, 0].max
  end

  def self.night_hours_needed
    [10 - night_hours, 0].max
  end

  # Instance methods
  def completed?
    ended_at.present?
  end

  def in_progress?
    !completed?
  end

  def duration_hours
    return 0 unless duration_minutes
    (duration_minutes / 60.0).round(2)
  end

  private

  def ended_at_after_started_at
    if ended_at <= started_at
      errors.add(:ended_at, "must be after start time")
    end
  end

  def calculate_duration
    return unless started_at && ended_at
    self.duration_minutes = ((ended_at - started_at) / 60).to_i
  end

  def determine_night_drive
    return unless started_at

    # Simple heuristic: 8pm - 6am is night
    # For production, could use sunrise/sunset API
    hour = started_at.hour
    self.is_night_drive = hour >= 20 || hour < 6
  end
end
```

---

## Phase 2: Routes & Controllers

### Step 2.1: Define Routes
Edit `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  root "drive_sessions#index"

  resources :drive_sessions, only: [:index, :new, :create, :edit, :update, :destroy] do
    member do
      post :complete
    end

    collection do
      get :export
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
```

### Step 2.2: Generate Controller
```bash
bin/rails generate controller DriveSession index new edit
```

### Step 2.3: Define Controller
Edit `app/controllers/drive_sessions_controller.rb`:

```ruby
class DriveSessionsController < ApplicationController
  before_action :set_drive_session, only: [:edit, :update, :destroy, :complete]

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
        headers['Content-Disposition'] = "attachment; filename=\"driving-log-#{Date.current}.csv\""
        headers['Content-Type'] = 'text/csv'
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
```

---

## Phase 3: Views & Frontend

### Step 3.1: Application Layout
Edit `app/views/layouts/application.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>Learner's Permit Tracker</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <header>
      <div class="container">
        <h1><%= link_to "IL Learner's Permit Tracker", root_path %></h1>
      </div>
    </header>

    <main>
      <div class="container">
        <% if notice.present? %>
          <div class="notice"><%= notice %></div>
        <% end %>

        <% if alert.present? %>
          <div class="alert"><%= alert %></div>
        <% end %>

        <%= yield %>
      </div>
    </main>

    <footer>
      <div class="container">
        <p>Illinois requires 50 hours total (including 10 hours at night)</p>
      </div>
    </footer>
  </body>
</html>
```

### Step 3.2: Index View
Create `app/views/drive_sessions/index.html.erb`:

```erb
<div class="dashboard">
  <div class="progress-summary">
    <div class="stat-card">
      <h2><%= @total_hours.round(1) %> / 50</h2>
      <p>Total Hours</p>
      <% if @hours_needed > 0 %>
        <small><%= @hours_needed.round(1) %> hours remaining</small>
      <% else %>
        <small class="complete">✓ Complete!</small>
      <% end %>
    </div>

    <div class="stat-card">
      <h2><%= @night_hours.round(1) %> / 10</h2>
      <p>Night Hours</p>
      <% if @night_hours_needed > 0 %>
        <small><%= @night_hours_needed.round(1) %> hours remaining</small>
      <% else %>
        <small class="complete">✓ Complete!</small>
      <% end %>
    </div>
  </div>

  <% if @in_progress %>
    <div class="in-progress-drive">
      <h3>Drive in Progress</h3>
      <p>
        <strong>Started:</strong> <%= @in_progress.started_at.strftime("%b %d, %Y at %I:%M %p") %>
      </p>
      <p>
        <strong>Driver:</strong> <%= @in_progress.driver_name %>
      </p>
      <%= button_to "Complete Drive", complete_drive_session_path(@in_progress),
                    class: "button-primary" %>
      <%= link_to "Edit", edit_drive_session_path(@in_progress), class: "button" %>
    </div>
  <% else %>
    <div class="actions">
      <%= link_to "Start New Drive", new_drive_session_path, class: "button-primary button-large" %>
      <%= link_to "Export Log (CSV)", export_drive_sessions_path(format: :csv), class: "button" %>
    </div>
  <% end %>

  <div class="drive-history">
    <h3>Recent Drives</h3>

    <% if @sessions.any? %>
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>Driver</th>
            <th>Duration</th>
            <th>Night</th>
            <th>Supervisor</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <% @sessions.each do |session| %>
            <tr>
              <td><%= session.started_at.strftime("%b %d, %Y") %></td>
              <td><%= session.driver_name %></td>
              <td><%= session.duration_hours %> hrs</td>
              <td><%= session.is_night_drive ? "🌙" : "☀️" %></td>
              <td><%= session.supervisor_name %></td>
              <td class="actions">
                <%= link_to "Edit", edit_drive_session_path(session) %>
                <%= button_to "Delete", drive_session_path(session),
                              method: :delete,
                              data: { turbo_confirm: "Are you sure?" },
                              class: "link-danger" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p class="empty-state">No drives recorded yet. Start your first drive!</p>
    <% end %>
  </div>
</div>
```

### Step 3.3: New/Edit Form Partial
Create `app/views/drive_sessions/_form.html.erb`:

```erb
<%= form_with model: drive_session, class: "drive-form" do |f| %>
  <% if drive_session.errors.any? %>
    <div class="error-messages">
      <h3><%= pluralize(drive_session.errors.count, "error") %> prevented this drive from being saved:</h3>
      <ul>
        <% drive_session.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="field">
    <%= f.label :driver_name, "Driver Name" %>
    <%= f.text_field :driver_name, required: true %>
  </div>

  <div class="field">
    <%= f.label :supervisor_name, "Supervisor Name (optional)" %>
    <%= f.text_field :supervisor_name %>
  </div>

  <div class="field">
    <%= f.label :started_at, "Start Time" %>
    <%= f.datetime_local_field :started_at, required: true %>
  </div>

  <% if drive_session.persisted? %>
    <div class="field">
      <%= f.label :ended_at, "End Time (optional)" %>
      <%= f.datetime_local_field :ended_at %>
    </div>
  <% end %>

  <div class="field">
    <%= f.label :notes, "Notes (optional)" %>
    <%= f.text_area :notes, rows: 3,
                    placeholder: "Road types, conditions, skills practiced..." %>
  </div>

  <div class="actions">
    <%= f.submit class: "button-primary" %>
    <%= link_to "Cancel", drive_sessions_path, class: "button" %>
  </div>
<% end %>
```

### Step 3.4: New View
Create `app/views/drive_sessions/new.html.erb`:

```erb
<h2>Start New Drive</h2>

<%= render "form", drive_session: @drive_session %>
```

### Step 3.5: Edit View
Create `app/views/drive_sessions/edit.html.erb`:

```erb
<h2>Edit Drive</h2>

<%= render "form", drive_session: @drive_session %>
```

### Step 3.6: CSV Export View
Create `app/views/drive_sessions/export.csv.erb`:

```erb
<%- headers = ["Date", "Start Time", "End Time", "Duration (hours)", "Night Drive", "Driver", "Supervisor", "Notes"] -%>
<%= CSV.generate_line(headers) -%>
<%- @sessions.each do |session| -%>
<%= CSV.generate_line([
  session.started_at.strftime("%m/%d/%Y"),
  session.started_at.strftime("%I:%M %p"),
  session.ended_at&.strftime("%I:%M %p"),
  session.duration_hours,
  session.is_night_drive ? "Yes" : "No",
  session.driver_name,
  session.supervisor_name,
  session.notes
]) -%>
<%- end -%>
```

---

## Phase 4: Styling

### Step 4.1: Application CSS
Edit `app/assets/stylesheets/application.css`:

```css
/*
 * This is a manifest file that'll be compiled into application.css
 */

/* Reset and base styles */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

:root {
  --color-primary: #2563eb;
  --color-primary-dark: #1e40af;
  --color-success: #16a34a;
  --color-danger: #dc2626;
  --color-background: #f9fafb;
  --color-surface: #ffffff;
  --color-border: #e5e7eb;
  --color-text: #1f2937;
  --color-text-light: #6b7280;
  --spacing-unit: 1rem;
  --border-radius: 8px;
  --max-width: 1200px;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  line-height: 1.6;
  color: var(--color-text);
  background-color: var(--color-background);
}

/* Layout */
.container {
  max-width: var(--max-width);
  margin: 0 auto;
  padding: 0 var(--spacing-unit);
}

header {
  background-color: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  padding: var(--spacing-unit) 0;
  margin-bottom: calc(var(--spacing-unit) * 2);
}

header h1 {
  font-size: 1.5rem;
  font-weight: 600;
}

header h1 a {
  color: var(--color-text);
  text-decoration: none;
}

main {
  min-height: calc(100vh - 200px);
  padding-bottom: calc(var(--spacing-unit) * 2);
}

footer {
  background-color: var(--color-surface);
  border-top: 1px solid var(--color-border);
  padding: calc(var(--spacing-unit) * 1.5) 0;
  margin-top: calc(var(--spacing-unit) * 3);
  text-align: center;
  color: var(--color-text-light);
  font-size: 0.875rem;
}

/* Notifications */
.notice,
.alert {
  padding: calc(var(--spacing-unit) * 0.75) var(--spacing-unit);
  border-radius: var(--border-radius);
  margin-bottom: var(--spacing-unit);
}

.notice {
  background-color: #dbeafe;
  color: #1e40af;
  border: 1px solid #93c5fd;
}

.alert {
  background-color: #fee2e2;
  color: #991b1b;
  border: 1px solid #fca5a5;
}

/* Dashboard */
.dashboard {
  display: flex;
  flex-direction: column;
  gap: calc(var(--spacing-unit) * 2);
}

.progress-summary {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: var(--spacing-unit);
}

.stat-card {
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  padding: calc(var(--spacing-unit) * 1.5);
  text-align: center;
}

.stat-card h2 {
  font-size: 2.5rem;
  font-weight: 700;
  color: var(--color-primary);
  margin-bottom: calc(var(--spacing-unit) * 0.5);
}

.stat-card p {
  font-size: 1.125rem;
  color: var(--color-text);
  margin-bottom: calc(var(--spacing-unit) * 0.25);
}

.stat-card small {
  color: var(--color-text-light);
  font-size: 0.875rem;
}

.stat-card small.complete {
  color: var(--color-success);
  font-weight: 600;
}

/* In-progress drive */
.in-progress-drive {
  background-color: #fef3c7;
  border: 2px solid #f59e0b;
  border-radius: var(--border-radius);
  padding: calc(var(--spacing-unit) * 1.5);
}

.in-progress-drive h3 {
  margin-bottom: var(--spacing-unit);
  color: #92400e;
}

.in-progress-drive p {
  margin-bottom: calc(var(--spacing-unit) * 0.5);
}

.in-progress-drive .button-primary {
  margin-top: var(--spacing-unit);
  margin-right: calc(var(--spacing-unit) * 0.5);
}

/* Actions */
.actions {
  display: flex;
  gap: var(--spacing-unit);
  flex-wrap: wrap;
}

/* Drive history */
.drive-history {
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  padding: calc(var(--spacing-unit) * 1.5);
}

.drive-history h3 {
  margin-bottom: var(--spacing-unit);
}

/* Table */
table {
  width: 100%;
  border-collapse: collapse;
  margin-top: var(--spacing-unit);
}

table th {
  text-align: left;
  padding: calc(var(--spacing-unit) * 0.75);
  background-color: var(--color-background);
  border-bottom: 2px solid var(--color-border);
  font-weight: 600;
  font-size: 0.875rem;
  color: var(--color-text-light);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

table td {
  padding: calc(var(--spacing-unit) * 0.75);
  border-bottom: 1px solid var(--color-border);
}

table tr:hover {
  background-color: var(--color-background);
}

table td.actions {
  text-align: right;
}

table td.actions a,
table td.actions button {
  margin-left: calc(var(--spacing-unit) * 0.5);
  font-size: 0.875rem;
}

/* Forms */
.drive-form {
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  padding: calc(var(--spacing-unit) * 2);
  max-width: 600px;
}

.field {
  margin-bottom: calc(var(--spacing-unit) * 1.5);
}

.field label {
  display: block;
  margin-bottom: calc(var(--spacing-unit) * 0.5);
  font-weight: 500;
  color: var(--color-text);
}

.field input[type="text"],
.field input[type="datetime-local"],
.field textarea {
  width: 100%;
  padding: calc(var(--spacing-unit) * 0.625);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  font-size: 1rem;
  font-family: inherit;
}

.field input:focus,
.field textarea:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
}

.field textarea {
  resize: vertical;
}

/* Error messages */
.error-messages {
  background-color: #fee2e2;
  border: 1px solid #fca5a5;
  border-radius: var(--border-radius);
  padding: var(--spacing-unit);
  margin-bottom: calc(var(--spacing-unit) * 1.5);
}

.error-messages h3 {
  color: #991b1b;
  font-size: 0.875rem;
  margin-bottom: calc(var(--spacing-unit) * 0.5);
}

.error-messages ul {
  margin-left: calc(var(--spacing-unit) * 1.25);
  color: #991b1b;
  font-size: 0.875rem;
}

/* Buttons */
.button,
.button-primary,
.button-large,
button[type="submit"],
input[type="submit"] {
  display: inline-block;
  padding: calc(var(--spacing-unit) * 0.625) calc(var(--spacing-unit) * 1.25);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  background-color: var(--color-surface);
  color: var(--color-text);
  text-decoration: none;
  font-size: 0.9375rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.button:hover {
  background-color: var(--color-background);
  border-color: var(--color-text-light);
}

.button-primary {
  background-color: var(--color-primary);
  color: white;
  border-color: var(--color-primary);
}

.button-primary:hover {
  background-color: var(--color-primary-dark);
  border-color: var(--color-primary-dark);
}

.button-large {
  padding: calc(var(--spacing-unit) * 0.875) calc(var(--spacing-unit) * 2);
  font-size: 1.125rem;
}

.link-danger {
  color: var(--color-danger);
  background: none;
  border: none;
  padding: 0;
  font-size: inherit;
  text-decoration: underline;
  cursor: pointer;
}

.link-danger:hover {
  color: #991b1b;
}

/* Empty state */
.empty-state {
  text-align: center;
  padding: calc(var(--spacing-unit) * 3) var(--spacing-unit);
  color: var(--color-text-light);
}

/* Mobile responsiveness */
@media (max-width: 768px) {
  .progress-summary {
    grid-template-columns: 1fr;
  }

  table {
    font-size: 0.875rem;
  }

  table th,
  table td {
    padding: calc(var(--spacing-unit) * 0.5);
  }

  .button-large {
    width: 100%;
  }
}
```

---

## Phase 5: Configuration

### Step 5.1: Setup Encrypted Credentials
```bash
# Edit credentials (will open in $EDITOR)
bin/rails credentials:edit
```

Add the following to your credentials:

```yaml
# Used for encrypting the database (if needed)
secret_key_base: <generated by Rails>

# Optional: If you want to add email notifications later
# smtp:
#   address: smtp.example.com
#   username: user@example.com
#   password: your-password
```

### Step 5.2: Configure Importmap (already set up by default)
Verify `config/importmap.rb` includes:

```ruby
# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
```

### Step 5.3: Configure Solid Queue (for background jobs)
Already included in Rails 8 by default. Verify `config/environments/production.rb`:

```ruby
config.active_job.queue_adapter = :solid_queue
```

### Step 5.4: Configure Solid Cache (for caching)
Already included in Rails 8 by default. Verify `config/environments/production.rb`:

```ruby
config.cache_store = :solid_cache_store
```

---

## Phase 6: Seeds & Test Data

### Step 6.1: Create Seed Data
Edit `db/seeds.rb`:

```ruby
# Clear existing data
DriveSession.destroy_all

# Create sample driver
driver_name = "Sarah Mitchell"

# Create some completed drives
20.times do |i|
  days_ago = rand(1..60)
  start_time = days_ago.days.ago.change(hour: rand(8..20), min: [0, 15, 30, 45].sample)
  duration = [30, 45, 60, 90, 120].sample
  end_time = start_time + duration.minutes

  DriveSession.create!(
    driver_name: driver_name,
    supervisor_name: ["Mom", "Dad", "Uncle Tom", "Aunt Jane"].sample,
    started_at: start_time,
    ended_at: end_time,
    notes: [
      "Highway practice, lane changes",
      "Neighborhood streets, stop signs",
      "Parking practice at mall",
      "Rush hour traffic experience",
      nil, nil # Some without notes
    ].sample
  )
end

puts "Created #{DriveSession.count} drive sessions"
puts "Total hours: #{DriveSession.total_hours.round(1)}"
puts "Night hours: #{DriveSession.night_hours.round(1)}"
```

### Step 6.2: Run Seeds
```bash
bin/rails db:seed
```

---

## Phase 7: Testing Setup

### Step 7.1: Model Test
Edit `test/models/drive_session_test.rb`:

```ruby
require "test_helper"

class DriveSessionTest < ActiveSupport::TestCase
  test "calculates duration on save" do
    session = DriveSession.create!(
      driver_name: "Test Driver",
      started_at: 1.hour.ago,
      ended_at: Time.current
    )

    assert_equal 60, session.duration_minutes
  end

  test "determines night drive based on start time" do
    # Night drive
    night_session = DriveSession.create!(
      driver_name: "Test Driver",
      started_at: Time.current.change(hour: 21),
      ended_at: Time.current.change(hour: 22)
    )
    assert night_session.is_night_drive

    # Day drive
    day_session = DriveSession.create!(
      driver_name: "Test Driver",
      started_at: Time.current.change(hour: 14),
      ended_at: Time.current.change(hour: 15)
    )
    assert_not day_session.is_night_drive
  end

  test "requires driver name" do
    session = DriveSession.new(started_at: Time.current)
    assert_not session.valid?
    assert_includes session.errors[:driver_name], "can't be blank"
  end

  test "calculates total hours" do
    DriveSession.create!(
      driver_name: "Test",
      started_at: 2.hours.ago,
      ended_at: 1.hour.ago
    )

    assert_equal 1.0, DriveSession.total_hours
  end
end
```

### Step 7.2: Controller Test
Edit `test/controllers/drive_sessions_controller_test.rb`:

```ruby
require "test_helper"

class DriveSessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get drive_sessions_url
    assert_response :success
  end

  test "should get new" do
    get new_drive_session_url
    assert_response :success
  end

  test "should create drive_session" do
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
end
```

### Step 7.3: Run Tests
```bash
bin/rails test
```

---

## Phase 8: Deployment Preparation

### Step 8.1: Production Database
For production, consider using PostgreSQL or staying with SQLite. If using SQLite, ensure proper backups.

Add to `.gitignore`:
```
/storage/*
!/storage/.keep
```

### Step 8.2: Dockerfile (if deploying with Docker/Kamal)
Rails 8 generates a default Dockerfile. Verify it exists and looks good:

```bash
ls -la Dockerfile
```

### Step 8.3: Environment Variables
For production deployment, set these environment variables:

- `RAILS_ENV=production`
- `RAILS_MASTER_KEY` (from `config/master.key`)
- `DATABASE_URL` (if using external database)

### Step 8.4: Precompile Assets (for production)
```bash
RAILS_ENV=production bin/rails assets:precompile
```

---

## Phase 9: Running the Application

### Step 9.1: Development
```bash
bin/dev
```

Access at: `http://localhost:3000`

### Step 9.2: Console Access
```bash
bin/rails console
```

### Step 9.3: Database Management
```bash
# Reset database
bin/rails db:reset

# Run migrations
bin/rails db:migrate

# Rollback migration
bin/rails db:rollback
```

---

## Phase 10: Optional Enhancements

### Enhancement Ideas (Post-MVP)

1. **Multiple Drivers Support**
   - Add a `Driver` model
   - Associate sessions with drivers
   - Track progress per driver

2. **Locations Tracking**
   - Add start/end location fields
   - Store as simple text or use geocoding

3. **Weather Conditions**
   - Add weather field (enum: clear, rain, snow)
   - Optional weather API integration

4. **Road Types**
   - Add road_type field (enum: highway, city, residential, rural)

5. **Notifications**
   - Email reminders after X days without practice
   - Progress milestones (25%, 50%, 75% complete)

6. **Photos/Attachments**
   - Add Active Storage for photos
   - Attach photos to driving sessions

7. **Printable Log**
   - PDF export using Prawn gem
   - Formatted for DMV submission

8. **PWA Features**
   - Service worker for offline support
   - "Add to Home Screen" capability
   - Push notifications

---

## Development Workflow Tips

### Following Fizzy Patterns

1. **Controllers**: Keep them thin, delegate to models
2. **Models**: Rich domain models with business logic
3. **Views**: Use partials for reusable components
4. **CSS**: Standard CSS, no preprocessors
5. **JavaScript**: Minimal, use Turbo/Stimulus when needed
6. **Routes**: RESTful resources, avoid custom actions when possible

### Code Organization
```
app/
├── controllers/
│   └── drive_sessions_controller.rb
├── models/
│   └── drive_session.rb
├── views/
│   ├── layouts/
│   │   └── application.html.erb
│   └── drive_sessions/
│       ├── index.html.erb
│       ├── new.html.erb
│       ├── edit.html.erb
│       ├── _form.html.erb
│       └── export.csv.erb
└── assets/
    └── stylesheets/
        └── application.css
```

---

## Troubleshooting

### Common Issues

**Issue**: "Zeitwerk::NameError"
- **Solution**: Ensure file names match class names (snake_case files, CamelCase classes)

**Issue**: Turbo form submissions not working
- **Solution**: Ensure `turbo-rails` is in `Gemfile` and importmap is configured

**Issue**: Styles not loading
- **Solution**: Check `application.css` is referenced in layout
- **Solution**: Restart server after CSS changes

**Issue**: Database locked (SQLite)
- **Solution**: Ensure no other processes are accessing the database
- **Solution**: Consider PostgreSQL for production

---

## Next Steps

1. Generate the Rails app: `rails new learners_permit_tracker`
2. Follow Phase 1 to set up the database
3. Follow Phase 2 to create controllers
4. Follow Phase 3 to build views
5. Follow Phase 4 to add styling
6. Follow Phase 5 for configuration
7. Follow Phase 6 to add seed data
8. Follow Phase 7 to add tests
9. Test the application locally
10. Deploy when ready

---

## Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Hotwire Documentation](https://hotwired.dev/)
- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Fizzy GitHub](https://github.com/basecamp/fizzy)

---

## License & Credits

This implementation plan is based on patterns from [37signals Fizzy](https://github.com/basecamp/fizzy).
Designed for tracking Illinois learner's permit driving requirements.
