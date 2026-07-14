import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="activity-calendar"
export default class extends Controller {
  static targets = ["day"]

  showDayInfo(event) {
    const dayElement = event.currentTarget
    const date = dayElement.dataset.date
    const state = dayElement.dataset.state

    const label = {
      day: "day drive",
      night: "night drive",
      both: "day & night drives",
      none: "no drives"
    }[state] || "no drives"

    const isMobile = !window.matchMedia("(hover: hover)").matches
    if (isMobile) {
      this.createToast(`${date}: ${label}`)
    }
  }

  createToast(message) {
    const container = document.getElementById("toast-container")
    const template = document.getElementById("toast-template")

    if (!container || !template) return

    // Clone the template content
    const toast = template.content.cloneNode(true)

    // Set the message in the toast content
    const content = toast.querySelector(".toast-content")
    content.textContent = message

    // Append to container (this will trigger the toast controller automatically)
    container.appendChild(toast)
  }
}
