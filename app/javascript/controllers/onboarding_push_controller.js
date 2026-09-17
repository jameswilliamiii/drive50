import { Controller } from "@hotwired/stimulus"
import { iosNeedsHomeScreenInstall, isPushSupported, subscribeToPush } from "push_subscribe"

export default class extends Controller {
  static targets = ["enable", "iosNote", "finishForm", "status"]

  connect() {
    if (!isPushSupported()) {
      this.disableEnable("Push notifications are not supported in this browser")
      return
    }

    if (iosNeedsHomeScreenInstall()) {
      if (this.hasIosNoteTarget) {
        this.iosNoteTarget.style.display = "block"
      }
      this.disableEnable("Install app to home screen to enable notifications")
    }
  }

  async enable(event) {
    const button = event.currentTarget
    const originalText = button.textContent
    button.disabled = true
    button.textContent = "Enabling..."

    try {
      await subscribeToPush()
      this.finishFormTarget.requestSubmit()
    } catch (error) {
      console.error("Error enabling push notifications:", error)
      button.disabled = false
      button.textContent = originalText
      this.updateStatus(error.message || "Failed to enable notifications", "error")
    }
  }

  disableEnable(message) {
    if (this.hasEnableTarget) {
      this.enableTarget.disabled = true
    }
    this.updateStatus(message, "error")
  }

  updateStatus(message, state = null) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("enabled", "disabled", "error")
    if (state) {
      this.statusTarget.classList.add(state)
    }
  }
}
