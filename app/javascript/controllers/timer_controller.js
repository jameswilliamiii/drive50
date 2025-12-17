import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="timer"
// Updates elapsed time display for in-progress drives
export default class extends Controller {
  static values = {
    startedAt: String
  }

  static targets = ["display"]

  connect() {
    // Update immediately and then every second to ensure accuracy
    // This ensures all browsers show the same time based on the start time
    this.updateTime()
    this.interval = setInterval(() => {
      this.updateTime()
    }, 1000) // Update every second for accuracy
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  updateTime() {
    if (!this.startedAtValue || !this.hasDisplayTarget) {
      return
    }

    const startedAt = new Date(this.startedAtValue)
    const now = new Date()
    const elapsedSeconds = Math.floor((now - startedAt) / 1000)
    const hours = Math.floor(elapsedSeconds / 3600)
    const minutes = Math.floor((elapsedSeconds % 3600) / 60)

    let displayText
    if (hours > 0) {
      displayText = `${hours}h ${minutes}m`
    } else {
      displayText = `${minutes}m`
    }

    this.displayTarget.textContent = displayText
  }
}

