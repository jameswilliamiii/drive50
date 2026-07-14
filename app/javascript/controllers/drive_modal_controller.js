import { Controller } from "@hotwired/stimulus"

// Lives on <body>; every drive row triggers it via click->drive-modal#open.
// The dialog is populated from the clicked row's data attributes so no server
// round-trip is needed. Times are stored as ISO (UTC) and formatted in the
// browser's timezone, matching how the LocalTime-rendered rows behave.
export default class extends Controller {
  static targets = [
    "dialog", "badge", "date", "type",
    "duration", "time", "driver", "driverRow", "notes", "notesSection"
  ]

  open(event) {
    // Clicks inside the kebab menu (button, dropdown, backdrop) manage their own
    // behavior — don't also open the detail modal.
    if (event.target.closest(".drive-row-actions")) return

    const d = event.currentTarget.dataset
    const night = d.driveNight === "true"
    const start = d.driveStartedAt ? new Date(d.driveStartedAt) : null
    const end = d.driveEndedAt ? new Date(d.driveEndedAt) : null

    this.dateTarget.textContent = start
      ? start.toLocaleDateString(undefined, { weekday: "long", year: "numeric", month: "long", day: "numeric" })
      : ""
    this.typeTarget.textContent = night ? "Night drive" : "Day drive"
    this.badgeTarget.classList.toggle("is-night", night)
    this.badgeTarget.classList.toggle("is-day", !night)

    this.durationTarget.textContent = d.driveDuration || "—"

    const fmt = (t) => t ? t.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" }) : ""
    this.timeTarget.textContent = start && end ? `${fmt(start)} – ${fmt(end)}` : fmt(start)

    if (d.driveDriver && d.driveDriver.trim()) {
      this.driverTarget.textContent = d.driveDriver
      this.driverRowTarget.hidden = false
    } else {
      this.driverRowTarget.hidden = true
    }

    if (d.driveNotes && d.driveNotes.trim()) {
      this.notesTarget.textContent = d.driveNotes
      this.notesSectionTarget.hidden = false
    } else {
      this.notesSectionTarget.hidden = true
    }

    if (this.dialogTarget.open) return
    // Native showModal() does not stop the page behind the backdrop from
    // scrolling, so lock the body ourselves; onClose restores it.
    document.body.style.overflow = "hidden"
    this.dialogTarget.showModal()
  }

  openOnKey(event) {
    if (event.key === "Enter" || event.key === " ") {
      if (event.target.closest(".drive-row-actions")) return
      event.preventDefault()
      this.open(event)
    }
  }

  // Button and backdrop paths: release the lock synchronously here rather than
  // leaning on the dialog's `close` event, which doesn't fire reliably.
  close() {
    document.body.style.overflow = ""
    this.dialogTarget.close()
  }

  // Escape closes the dialog natively (firing cancel/close); this releases the
  // lock for that path.
  onClose() {
    document.body.style.overflow = ""
  }

  disconnect() {
    document.body.style.overflow = ""
  }

  // Native <dialog> click lands on the dialog element itself when the backdrop
  // (outside the card) is clicked.
  backdropClick(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
