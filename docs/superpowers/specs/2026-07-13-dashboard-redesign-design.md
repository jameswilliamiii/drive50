# Dashboard Redesign — Design Spec

**Date:** 2026-07-13
**Branch:** `redesign-dashboard`
**Status:** Approved design, ready for implementation planning

## Overview

Redesign the Drive50 dashboard (`drive_sessions#index`) as one cohesive system that is more **motivating**, more **modern**, and more **informative** than the current three-rings-in-a-row layout. The redesign replaces the two circular progress rings and the count-based activity grid, and refreshes the Recent Drives list.

The unifying visual idea is **day vs. night** — the two things this app fundamentally tracks. A dusk color language (day = amber, night = indigo) runs through every component, drawn from tokens that already exist in `app/assets/stylesheets/00-variables.css` (the day/night badge colors).

The dashboard is composed of three stacked, full-width components in a single centered column:

1. **Hero** — the "Dusk" panel: total-hours headline + derived insights
2. **Activity** — the "Driving rhythm" card: streak-led editorial layout with a 3-week day/night grid
3. **Recent drives** — icon-led rows (redesign of the current table)

All three must support **light and dark mode** (system-preference driven, matching the app's existing `prefers-color-scheme` + `data-theme` approach) and look **excellent on mobile** (the majority of users are on phones).

### Non-goals / out of scope

- No changes to the "All drives" page (`drive_sessions#all`), forms, auth, or navigation chrome (header, bottom nav, FAB).
- No changes to the in-progress drive banner or FAB *behavior* — see "In-progress drives" below.
- No new gems or JS build step. ImportMaps + Stimulus + inline SVG only.

## Component 1 — Hero ("Dusk" panel)

A branded gradient panel that anchors the page. Unlike the cards below it, the hero is a **constant colored panel in both themes** (it does not flip to a white surface in light mode); only its gradient *deepens* in dark mode so it belongs against the near-black page.

### Layout

- **Top row (flex, space-between):**
  - Left: large total-hours number (`31.0`, font-weight ~820, `letter-spacing: -0.02em`) with a caption beneath (`of 50 hours · 19h to go`).
  - Right: a quiet right-aligned stat — uppercase micro-label `Projected finish` over a value (`Early October`). No icon, no emoji.
- **Progress bar:** a single slim horizontal track showing total progress toward 50h, split into two stacked segments — **day** (amber) then **night** (indigo) — so the bar encodes that night hours are a *subset* of total.
- **Chips row:** four glass chips (translucent white, `backdrop-filter: blur`) — `Day` (23.3), `Night` (7.7 / 10), `Pace` (2.5 h/wk), `Drives` (24). The Day chip key is amber-tinted, the Night chip key is indigo-tinted.

### Color

- Light gradient: `radial-gradient(135% 135% at 15% -10%, #4f46e5 0%, #362e8f 45%, #1c1b40 100%)`.
- Dark gradient: `radial-gradient(135% 135% at 15% -10%, #2b2870 0%, #1f1c49 46%, #121129 100%)` plus a hairline `1px solid rgba(129,140,248,.16)` border to lift it off the `#020617` page, and a reduced shadow.
- **Sunset horizon:** a subtle warm glow rising from the bottom edge via `::after` — `radial-gradient(120% 100% at 50% 145%, rgba(251,191,36,.30), transparent 68%)`, dimmed (~`.17` alpha) in dark mode. This replaced an earlier corner "blob" and should stay subtle.
- Progress fills: day `linear-gradient(90deg,#fcd34d,#f59e0b)`, night `linear-gradient(90deg,#a5b4fc,#818cf8)`.

### Mobile

- Number scales down (~3.5rem). The `Projected finish` stat drops **below** the number (full-width, separated by a hairline top border) and may append the pace inline (`Early October · at 2.5h / week`).
- Chips become a 2×2 grid.

### Replaces

- `_progress_summary.html.erb` is rewritten to render the hero (keeping the `#progress-summary` wrapper id — see "Real-time updates").
- `_stat_card.html.erb` and the two circular-progress rings are no longer used on the dashboard. The `circular_progress` helper in `app/helpers/drive_session_helper.rb` becomes dead code if nothing else references it — confirm and remove.

## Component 2 — Activity ("Driving rhythm" card)

Streak-led editorial layout on a standard card surface (white in light, `#0f172a` in dark). Typography — not more data — fills the space, and the layout deliberately echoes the hero's big-number + uppercase-micro-label signature so the two read as one system.

### Layout (desktop)

Two columns inside the card body:

- **Left (statement, flex: 1):**
  - Big streak number (e.g. `3`, amber `#f59e0b`, weight ~820) with uppercase label `DAY STREAK` beneath.
  - A human sentence: **"You've driven 16 of the last 21 days."** (the bolded fraction is `active_days / 21`).
  - A row of three mini-stats using the hero's micro-label typography: `This week` (4.5h), `Last week` (3.0h), `Best` (6 days).
- **Right (calendar, fixed ~250px):**
  - Weekday header row `S M T W T F S`.
  - A **3-week grid** (7 columns × 3 rows, Sunday-aligned) of rounded day cells.
  - Legend: Day / Night / Both.

### The day/night grid

- The grid shows **3 calendar weeks** (the current week plus the two prior), Sunday-aligned, so columns line up under the weekday header. Today's cell gets a ring (`outline: 2px solid #2563eb`; `#60a5fa` in dark). Future days in the current week render as empty/muted.
- Each cell's state is driven by that day's completed drives:
  - **none** → neutral track (`#f1f5f9` light / `#1e293b` dark, with a `1px` border).
  - **day only** → solid amber.
  - **night only** → solid indigo.
  - **both** → **angled split**: `linear-gradient(135deg, <amber> 0 50%, <night> 50% 100%)` (amber top-left, indigo bottom-right). This "angled split" was chosen over a dusk gradient for legibility at small sizes.
- **Per-theme shades** (this is the key palette rule — the earlier bug was reusing light shades in dark):
  - Light: day `#f59e0b`, night `#6366f1`.
  - Dark: day `#fbbf24`, night `#a5b4fc` (the dark-mode badge icon colors).

### Mobile

- The two columns stack: the statement (streak number, label, sentence, mini-stats) on top, then the 3-week grid full-width with cells scaling to fill (`aspect-ratio: 1`), then the legend.

### Replaces

- `_activity_calendar.html.erb` is rewritten. It currently renders a 28-day, count-based (level 0–4) grid via `activity_calendar_data`; the new grid is 21 days, day/night-state based. The `activity_calendar_controller.js` (click-a-day-for-info) can be preserved/adapted for the new cells if we keep tap-to-inspect; otherwise the title attribute carries the date + day/night summary.

## Component 3 — Recent drives (icon-led rows)

A visual refresh of the current table. **All existing fields and actions are preserved**: date, day/night, duration, notes, Edit, Delete. Top 3 completed drives with a "View all →" link, same as today.

### Row anatomy (desktop)

`[ tinted sun/moon badge ] [ date (bold) + note (muted, truncated) ] [ Duration label + value ] [ ⋮ ]`

- **Badge:** a rounded square (~36–38px) with the day/night icon (`icon_sun` / `icon_moon`). Backgrounds use the existing badge tokens — light: day `#fef3c7`/`#f59e0b`, night `#eef2ff`/`#6366f1`; dark: day `#78350f`/`#fbbf24`, night `#312e81`/`#a5b4fc`.
- **Note under date:** solves the awkward empty desktop "Notes" column. When a drive has no note, show a plain descriptor (`Day drive` / `Night drive`). Long notes truncate with ellipsis.
- **Duration:** right-aligned, bold, with a small uppercase `Duration` label above it on desktop.
- Rows separated by hairline top borders; subtle hover background on desktop.

### Mobile

- Single tidy row: badge → date + note stack → compressed duration (`45m`, `1h 10m`) → `⋮`.
- The `⋮` opens the **existing bottom action sheet** (Edit / Delete / Cancel sliding up from the bottom with a dimmed, blurred backdrop). **This interaction is unchanged** — we keep the `card-menu` Stimulus controller, its backdrop element, and the `card-menu.css` bottom-sheet styles exactly as-is. Only the row's *visual markup* changes.

### Replaces (dashboard-only — do not touch the shared table partials)

`_session_row.html.erb` and `_table_header.html.erb` are **shared** with the out-of-scope All-drives page (`all.html.erb` renders them into a `<table>`/`<tbody id="sessions-tbody">`, `_pagination_frame.turbo_stream.erb` appends `_session_row` `<tr>`s into `sessions-tbody` for infinite scroll, and `DriveSession#broadcast_create/#broadcast_update` append `_session_row` into `sessions-tbody` / replace individual `<tr>`s by `dom_id`). **These two partials must stay exactly as-is** so `#all` and those `<tr>` flows keep working.

Therefore the dashboard gets its **own** recent-drives markup. **There are three dashboard render sites of `#recent-drives-table`, and all three must switch to the new markup:**

1. `index.html.erb` — initial dashboard render.
2. `DriveSession#broadcast_recent_drives_table` — live re-render on create/update.
3. `destroy.turbo_stream.erb` — re-renders `#recent-drives-table` after **any** drive is deleted (from either page). Note: this file targets the *dashboard's* `recent-drives-table`, **not** `sessions-tbody`; today it renders the `_session_row` collection plus a `<tr><td colspan="5">` empty state. It must be updated to render the new dashboard row markup and a **non-table** empty state.

Concretely:

- `_recent_drives_table.html.erb` (dashboard-only; rendered by `index.html.erb`, `broadcast_recent_drives_table`, and — for consistency — `destroy.turbo_stream.erb`) is rewritten from a `<table>` into the icon-led list container, keeping its `#recent-drives-table` wrapper id, and owns the new non-table empty state.
- Introduce a new dashboard row partial (e.g. `_recent_drive_row.html.erb`) for the icon-led row structure. Individual dashboard rows do **not** need `dom_id`-targeted updates — the whole `#recent-drives-table` is replaced wholesale — so per-row ids are optional here.
- The All-drives page keeps using `_session_row` / `_table_header` unchanged; its table, infinite scroll, and `sessions-tbody` appends are unaffected.

## Data & derived statistics

The hero and activity card introduce derived metrics. These should be computed server-side, timezone-aware (using `user.timezone || "UTC"`), and added to / alongside `DriveSessionStatistics.statistics_for`.

| Metric | Definition |
|---|---|
| `day_hours` | `total_hours - night_hours` |
| `weekly_pace` | Completed hours in the trailing 4 weeks ÷ 4. If less than 4 weeks of history exists, divide by weeks since the first drive (min 1). |
| `projected_finish` | `hours_needed / weekly_pace` → weeks remaining → a date, formatted loosely ("Early October"). If `weekly_pace` is 0 or `hours_needed` is 0, show a graceful fallback (see edge cases). |
| `drives_count` | Count of completed drives. |
| `current_streak` | Consecutive calendar days (user tz) with ≥1 completed drive, counting back from the most recent active day; considered "current" only if that day is today or yesterday, else 0. (Product decision — call out in review.) |
| `best_streak` | Longest run of consecutive active days ever. |
| `this_week_hours` / `last_week_hours` | Completed hours in the current / previous calendar week (Sunday-start, to match the grid). |
| `active_days` | Number of days with ≥1 completed drive within the 21-day window (denominator is always 21). |
| activity states | For each of the 21 days: whether it had day drives, night drives, both, or none. |

- Add a method (e.g. `activity_day_states(timezone:)`) that returns per-date day/night state, analogous to the existing `activity_by_date`. Add a helper that expands it into **3 Sunday-aligned calendar weeks** (current week + two prior = 21 cells) with `today`/`future` flags. Note: this must Sunday-align, **unlike** the existing `activity_calendar_data`, which lays out a trailing N-day window without weekday alignment — do not reuse it as-is, or the weekday columns will be misaligned.
- **`active_days` uses a different window on purpose:** it is a trailing **last-21-days** count (denominator always 21, matching the "16 of the last 21 days" copy), which is independent of how many *past* cells the Sunday-aligned grid happens to contain (that varies 15–21 depending on today's weekday). The trailing-21 query always covers every past cell in the grid, so one query can feed both. Keep the two windows conceptually distinct in the code.
- Keep these computations reasonably efficient — prefer grouped queries over per-day queries (the current `activity_by_date` groups in Ruby; streak/week math can operate on a single ordered pull of completed drives' `started_at` + `is_night_drive` + `duration_minutes`).

## Real-time updates (must not regress)

The `DriveSession` model broadcasts Turbo Stream updates on create/update/destroy (`broadcast_progress_summary`, `broadcast_recent_drives_table`, etc.). The redesign must preserve the broadcast targets so live updates keep working:

- `#progress-summary` — re-rendered `_progress_summary` (now the hero). The `broadcast_progress_summary` method must pass the new derived stats into the partial.
- `#recent-drives-table` — re-rendered wholesale as the new icon-led dashboard list (top 3). The dashboard list is always replaced as a unit, so it does not rely on per-row `dom_id` targeting.
- `#sessions-tbody` and per-row `dom_id(session)` — these belong to the **All-drives** page and its `_session_row` `<tr>`s, which are unchanged. Do not repoint these at the dashboard partials.
- The activity data passed into the progress-summary broadcast changes shape (day/night states, 21 days) — update the model's broadcast call and the new Sunday-aligning helper together.

### In-progress drives

- The existing **in-progress banner** (`shared/_in_progress_banner`, streamed via `#in-progress-banner-container`) and the **FAB** (`#fab-new-drive-wrapper`) remain the live UI for an active drive and are **unchanged**.
- The old desktop-only in-progress **stat card** (`_in_progress_drive` rendered inside `_progress_summary`, hidden on mobile) is removed from the dashboard, since the banner already covers this. Update `DriveSession#broadcast_create` / `#broadcast_update` so they no longer target the removed `in-progress-drive` element; the `in-progress-banner-container` and `fab-new-drive-wrapper` broadcasts stay.

## Styling approach

- Extend the existing CSS in `app/assets/stylesheets/` (primarily `cards.css`, plus a new file if a component grows large). Reuse `00-variables.css` tokens; add any new tokens (e.g. day/night grid shades) there so light/dark stay centralized.
- Numbers use `font-feature-settings: "tnum" 1` for tabular alignment.
- Respect the existing spacing scale, radius tokens (`--border-radius-lg`, etc.), and shadow tokens.

## Edge cases

- **No drives yet:** hero shows `0.0 of 50`, projected finish → "Keep driving" (or similar), pace `0`. Activity card shows `0 day streak`, "You've driven 0 of the last 21 days," empty grid. Recent drives keeps the existing empty state ("No drives recorded yet. Start your first drive!").
- **Pace is 0 but hours exist** (no drives in the trailing window): projected finish shows a neutral fallback rather than "Infinity/NaN".
- **Goal met:** total ≥ 50 and/or night ≥ 10 — show a "Complete!" treatment consistent with the app's existing `stat-complete` styling; projected finish becomes "Done" / hidden.
- **Future days** in the current week (grid) render muted/empty, never as "missed."
- **Long notes** truncate with ellipsis; **missing notes** fall back to `Day drive` / `Night drive`.
- **Streak "today not yet driven":** decide whether an untouched today breaks the streak visually; per the definition above, a streak stays "current" if the last active day was today or yesterday.

## Testing

- **Model/stat tests:** unit-test each derived metric (`weekly_pace`, `projected_finish`, `current_streak`, `best_streak`, `this_week_hours`/`last_week_hours`, `active_days`, activity day/night states), including timezone handling and the edge cases above (no drives, pace 0, goal met, DST boundaries reuse the existing night-drive test patterns).
- **View/partial tests:** hero renders with correct numbers and fallbacks; activity grid renders 21 cells with correct states and today marker; recent-drives rows render badge/date/note/duration and both desktop actions + mobile bottom-sheet markup.
- **System tests / manual:** verify light and dark mode, mobile widths, and that Turbo Stream broadcasts still update the hero, recent drives, and in-progress banner live when a drive is created/completed/deleted.

## Reference mockups

Interactive mockups produced during brainstorming live under `.superpowers/brainstorm/` (gitignored). Key final screens: `dusk-v2.html` (hero), `activity-typographic.html` Option A (activity), `recent-mobile-v2.html` (recent drives mobile), `full-dashboard.html` (assembled).
