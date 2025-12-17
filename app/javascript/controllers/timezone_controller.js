import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="timezone"
// Detects user's timezone and sends it with form submissions
export default class extends Controller {
  static targets = ["timezone"]

  connect() {
    // Get user's timezone from browser
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone

    // Set the hidden timezone field
    if (this.hasTimezoneTarget) {
      this.timezoneTarget.value = timezone
    }
  }
}

