import { ModalDialogController } from "helpers/modal_dialog"

// Lives on <body>; every drive row triggers it via click->drive-modal#open.
// The dialog is populated from the clicked row's data attributes so no server
// round-trip is needed. Times are stored as ISO (UTC) and formatted in the
// browser's timezone, matching how the LocalTime-rendered rows behave.
export default class extends ModalDialogController {
  static targets = [
    "badge", "date", "type",
    "duration", "time", "split", "splitRow", "driver", "driverRow", "notes", "notesSection"
  ]

  open(event) {
    // Clicks inside the kebab menu (button, dropdown, backdrop) manage their own
    // behavior — don't also open the detail modal.
    if (event.target.closest(".drive-row-actions")) return

    const d = event.currentTarget.dataset
    // "day" | "night" | "mixed", classified once server-side; the label comes with
    // it so the wording cannot drift from the row's.
    const kind = d.driveKind
    const mixed = kind === "mixed"
    const start = d.driveStartedAt ? new Date(d.driveStartedAt) : null
    const end = d.driveEndedAt ? new Date(d.driveEndedAt) : null

    this.dateTarget.textContent = start
      ? start.toLocaleDateString(undefined, { weekday: "long", year: "numeric", month: "long", day: "numeric" })
      : ""
    this.typeTarget.textContent = d.driveKindLabel
    this.badgeTarget.classList.toggle("is-night", kind !== "day")
    this.badgeTarget.classList.toggle("is-day", kind === "day")

    this.durationTarget.textContent = d.driveDuration || "—"

    this.splitRowTarget.hidden = !mixed
    if (mixed) {
      this.splitTarget.textContent = `${d.driveDayDuration} day · ${d.driveNightDuration} night`
    }

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

    this.showDialog()
  }

  openOnKey(event) {
    if (event.key === "Enter" || event.key === " ") {
      if (event.target.closest(".drive-row-actions")) return
      event.preventDefault()
      this.open(event)
    }
  }
}
