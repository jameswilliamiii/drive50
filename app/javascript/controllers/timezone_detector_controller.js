import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="timezone-detector"
// Automatically detects and saves user's timezone on page load
export default class extends Controller {
  static values = {
    current: String // Current timezone from server
  }

  connect() {
    this.detectAndSave()
  }

  detectAndSave() {
    try {
      const detectedTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone

      // Only send if timezone is detected and different from current
      if (detectedTimezone && detectedTimezone !== this.currentValue) {
        this.saveTimezone(detectedTimezone)
      }
    } catch (error) {
      console.error('Timezone detection error:', error)
    }
  }

  async saveTimezone(timezone) {
    try {
      const response = await fetch('/timezone', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ timezone: timezone })
      })

      if (response.ok) {
        console.log('Timezone saved:', timezone)
        // Update the current value so we don't send it again
        this.currentValue = timezone
      }
    } catch (error) {
      console.error('Failed to save timezone:', error)
    }
  }
}
