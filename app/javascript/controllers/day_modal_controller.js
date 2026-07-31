import { ModalDialogController } from "helpers/modal_dialog"

// Lives on <body>; every Momentum grid cell triggers it via day-modal#open.
// Populated from the cell's data-day-summary JSON, so tapping a day costs no
// server round-trip — the same approach as the drive-detail modal. Times are
// preformatted server-side in the zone the cell was grouped by, so the heading
// and the rows always describe the same local day.
export default class extends ModalDialogController {
  static targets = [
    "date", "summary", "totals", "dayRow", "dayTotal", "nightRow", "nightTotal",
    "list", "empty", "rowTemplate"
  ]

  open(event) {
    // The payload is server-rendered on every cell this action is bound to, so a
    // parse failure is a bug worth surfacing rather than swallowing.
    const summary = JSON.parse(event.currentTarget.dataset.daySummary)

    this.dateTarget.textContent = summary.label
    this.summaryTarget.textContent = summary.count
      ? `${summary.count} ${summary.count === 1 ? "drive" : "drives"} · ${summary.total}`
      : "No drives"

    this.setTotal(this.dayRowTarget, this.dayTotalTarget, summary.day)
    this.setTotal(this.nightRowTarget, this.nightTotalTarget, summary.night)
    this.totalsTarget.hidden = !summary.day && !summary.night

    this.listTarget.replaceChildren(...summary.drives.map((drive) => this.buildRow(drive)))
    this.emptyTarget.hidden = summary.drives.length > 0

    this.showDialog()
  }

  buildRow(drive) {
    const row = this.rowTemplateTarget.content.cloneNode(true)
    const el = row.querySelector(".day-modal-drive")

    el.classList.add(`is-${drive.kind}`)
    el.querySelector(".day-modal-drive-time").textContent = drive.time
    el.querySelector(".day-modal-drive-duration").textContent = drive.duration

    return row
  }

  setTotal(row, value, text) {
    row.hidden = !text
    if (text) value.textContent = text
  }
}
