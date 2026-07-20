# Mobile CSV Export via Web Share + Rotation Layout Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the iOS PWA CSV export from trapping users in a chrome-less download view, and stop the layout from breaking when the device rotates back to portrait.

**Architecture:** Progressive enhancement on the existing export links — a small Stimulus controller intercepts the click only when the browser can share a file (`navigator.canShare({files})`), fetches the existing `/drive_sessions/export.csv` endpoint, and hands the CSV to the native share sheet (an overlay that returns the user to the PWA). Everywhere the API is absent, the link falls through to today's normal download. Separately, two CSS changes make rotation deterministic: disable iOS text auto-inflation and normalize stray viewport-height units.

**Tech Stack:** Rails 8.1, Hotwire/Stimulus (importmap, eager-loaded controllers), plain CSS. No new dependencies, no controller/route/endpoint changes.

---

## Why the tests look different here

This change is client-side (Web Share JS) and presentational (CSS). Neither is meaningfully exercisable in this repo's automated setup: there is no JS test harness or `test/system/` directory, and the Web Share sheet + iOS rotation behavior cannot run headless. The honest verification story is:

- **Automated gate (regression):** the existing controller test `test/controllers/drive_sessions_controller_test.rb:107` proves the export endpoint — the fallback path every unsupported browser still uses — is unchanged. Plus `bin/rubocop`.
- **Manual gate (the actual feature):** an on-device checklist (Task 3) the human runs on a real iPhone PWA.

Do not fabricate JS/system tests that assert nothing real. If a JS harness is added later, the controller becomes testable then.

---

## File Structure

- **Create** `app/javascript/controllers/export_controller.js` — the only new unit. Sole responsibility: intercept an export link and route it through Web Share when supported, else let it download. Auto-registers via the existing `eagerLoadControllersFrom("controllers", ...)` in `app/javascript/controllers/index.js` — no manual registration.
- **Modify** `app/views/shared/_bottom_nav.html.erb` — add controller + action data attributes to the export link.
- **Modify** `app/views/shared/_header.html.erb` — same, on the menu export link.
- **Modify** `app/assets/stylesheets/01-reset.css` — add `html { -webkit-text-size-adjust: 100% }`.
- **Modify** `app/assets/stylesheets/layout-container.css`, `drive-modal.css`, `card-menu.css` — normalize `vh` → `svh`/`dvh`.

---

## Task 0: Branch

- [ ] **Step 1: Create a feature branch** (we're on `main`)

```bash
git checkout -b mobile-export-and-rotation
```

---

## Task 1: Rotation layout fixes (CSS)

Ship this first — it's independent of the export work and the highest-confidence fix.

**Files:**
- Modify: `app/assets/stylesheets/01-reset.css`
- Modify: `app/assets/stylesheets/layout-container.css:11`
- Modify: `app/assets/stylesheets/drive-modal.css:21`
- Modify: `app/assets/stylesheets/card-menu.css:93`

- [ ] **Step 1: Disable iOS text auto-inflation**

In `app/assets/stylesheets/01-reset.css`, add an `html` rule directly after the `* { ... }` block (before the `body` rule):

```css
html {
  /* iOS inflates text on rotate-to-landscape and often fails to reset it on
     rotate-back, breaking portrait layout. Pin it so rotation is a no-op. */
  -webkit-text-size-adjust: 100%;
}
```

- [ ] **Step 2: Normalize stray viewport-height units**

Match the `svh`/`dvh` units already used elsewhere in these files so heights recompute predictably across rotation.

`app/assets/stylesheets/layout-container.css:11` — change `100vh` to `100svh`:
```css
  min-height: calc(100svh - 200px);
```

`app/assets/stylesheets/drive-modal.css:21` — change `100vh` to `100dvh` (matches the `85dvh` already at line 217):
```css
  max-height: calc(100dvh - 2 * var(--spacing-2xl));
```

`app/assets/stylesheets/card-menu.css:93` — change `90vh` to `90dvh`:
```css
  max-height: calc(90dvh - 80px - env(safe-area-inset-bottom));
```

- [ ] **Step 3: Sanity-check nothing else still uses bare `vh`**

Run: `grep -rn "[0-9]vh" app/assets/stylesheets/`
Expected: no results (all remaining height units are `svh` or `dvh`). If a result appears, evaluate whether it should also be normalized.

- [ ] **Step 4: Rubocop (CSS isn't linted, but keep the suite green)**

Run: `bin/rubocop`
Expected: no new offenses.

- [ ] **Step 5: Commit**

```bash
git add app/assets/stylesheets/
git commit -m "Fix iOS PWA layout breaking on rotate-back to portrait"
```

---

## Task 2: Web Share export controller

**Files:**
- Create: `app/javascript/controllers/export_controller.js`
- Modify: `app/views/shared/_bottom_nav.html.erb:13-18`
- Modify: `app/views/shared/_header.html.erb:33-37`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/export_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="export"
//
// Progressive enhancement for the CSV export links. When the browser can share
// a file (iOS/Android PWA, desktop Chrome/Edge), intercept the click and hand
// the CSV to the native share sheet — an overlay that returns the user to the
// PWA, instead of the chrome-less download view that traps iOS standalone users.
// When file sharing is unsupported, we never preventDefault, so the link falls
// through to a normal browser download.
export default class extends Controller {
  share(event) {
    // Probe with an empty file — canShare validates the type, not the bytes.
    const probe = new File([""], "probe.csv", { type: "text/csv" })
    if (!navigator.canShare?.({ files: [probe] })) return

    event.preventDefault()
    this.shareCsv(this.element.href)
  }

  async shareCsv(url) {
    try {
      const response = await fetch(url, { headers: { Accept: "text/csv" } })
      if (!response.ok) throw new Error(`Export request failed: ${response.status}`)

      const blob = await response.blob()
      const file = new File([blob], this.filenameFrom(response), { type: "text/csv" })
      await navigator.share({ files: [file], title: "Drive50 Log" })
    } catch (error) {
      if (error.name === "AbortError") return // user dismissed the share sheet
      window.location.href = url // any real failure → fall back to a normal download
    }
  }

  filenameFrom(response) {
    const disposition = response.headers.get("Content-Disposition") || ""
    return disposition.match(/filename="?([^"]+)"?/)?.[1] || "driving-log.csv"
  }
}
```

Notes for the implementer:
- `this.element.href` is the absolute export URL because the controller is attached to the `<a>` itself.
- The endpoint already sets `Content-Disposition: attachment; filename="driving-log-<date>.csv"` (see `drive_sessions_controller.rb:101`), so `filenameFrom` preserves the dated filename; `fetch` ignores the `attachment` disposition and just returns the body.
- `fetch` is same-origin and sends the session cookie automatically — no credentials option needed.
- No manual Stimulus registration: `index.js` eager-loads every `*_controller.js`.

- [ ] **Step 2: Wire up the bottom-nav export link**

In `app/views/shared/_bottom_nav.html.erb`, add `controller` and `action` to the export link's `data:` hash (keep `turbo: false`):

```erb
  <%= link_to export_drive_sessions_path(format: :csv),
              data: { turbo: false, controller: "export", action: "click->export#share" },
              class: "bottom-nav-item #{'active' if request.path == export_drive_sessions_path(format: :csv)}" do %>
    <%= bottom_nav_icon(:export, active: request.path == export_drive_sessions_path(format: :csv), size: 24, class: "bottom-nav-icon") %>
    <span class="bottom-nav-label">Export</span>
  <% end %>
```

- [ ] **Step 3: Wire up the header-menu export link**

In `app/views/shared/_header.html.erb`, do the same:

```erb
            <%= link_to export_drive_sessions_path(format: :csv),
                        data: { turbo: false, controller: "export", action: "click->export#share" },
                        class: "menu-item" do %>
              <%= icon(:export, size: 20, class: "menu-item-icon") %>Export Drive Log
            <% end %>
```

- [ ] **Step 4: Confirm the fallback endpoint is untouched**

Run: `bin/rails test test/controllers/drive_sessions_controller_test.rb`
Expected: PASS — including "should export drive sessions as CSV". This is the download path every unsupported browser still takes; it must not regress.

- [ ] **Step 5: Rubocop**

Run: `bin/rubocop`
Expected: no new offenses.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/export_controller.js app/views/shared/_bottom_nav.html.erb app/views/shared/_header.html.erb
git commit -m "Share CSV export via native share sheet where supported"
```

---

## Task 3: On-device verification (manual — human runs this)

Automated tests can't reach any of this behavior; confirm on a real device before merging.

- [ ] **iOS PWA, export:** Open Drive50 as an installed PWA (Add to Home Screen). Tap Export (bottom nav) and Export Drive Log (header menu). Expected: the native share sheet appears **over** the app; save to Files / Mail; dismiss → you are **back in Drive50**, not stranded on a download screen or the home screen.
- [ ] **iOS PWA, share sheet content:** The shared file is named `driving-log-<today>.csv` and opens with the correct header row and your completed drives.
- [ ] **iOS PWA, cancel:** Open the share sheet and cancel it. Expected: nothing happens, you stay in the app (no error, no navigation).
- [ ] **Desktop Safari (unsupported):** Click Export. Expected: normal file download (unchanged from today). Desktop Chrome/Edge will instead show a share dialog — this is the accepted trade-off of pure capability detection.
- [ ] **iOS PWA, rotation:** Rotate to landscape and back to portrait on a few screens (dashboard, all-drives list, an open modal, the header menu). Expected: portrait layout returns to normal with no oversized text or clipped/overflowing containers.

---

## Rollback

Both commits are self-contained. Reverting the Task 2 commit restores the plain-download links (the endpoint never changed); reverting the Task 1 commit restores the prior CSS. Neither touches data or migrations.
