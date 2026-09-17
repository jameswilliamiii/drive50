import { Controller } from "@hotwired/stimulus"
import { iosNeedsHomeScreenInstall, isPushSupported, subscribeToPush } from "push_subscribe"

export default class extends Controller {
  static targets = ["toggle", "status", "iosNote", "toggleLabel", "weeklyWrap", "weeklyToggle"]
  static values = {
    subscribed: Boolean
  }

  async connect() {
    if (!isPushSupported()) {
      this.updateStatus("Push notifications are not supported in this browser", "error")
      this.disableToggle()
      this.syncWeeklyPreferenceUi(false)
      return
    }

    const iosNeedsInstall = this.showIosNoteIfNeeded()

    if (iosNeedsInstall) {
      this.updateStatus("Install app to home screen to enable notifications", "error")
      this.disableToggle()
      this.syncWeeklyPreferenceUi(false)
      return
    }

    await this.checkSubscription()
  }

  showIosNoteIfNeeded() {
    if (!this.hasIosNoteTarget) return false

    if (iosNeedsHomeScreenInstall()) {
      this.iosNoteTarget.style.display = "block"
      return true
    }

    return false
  }

  async checkSubscription() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      this.subscribedValue = !!subscription
      this.updateToggleState()
      this.syncWeeklyPreferenceUi(this.subscribedValue)

      if (subscription) {
        this.updateStatus("✓ Notifications enabled", "enabled")
      } else {
        this.updateStatus("Notifications disabled", "disabled")
      }
    } catch (error) {
      console.error("Error checking subscription:", error)
      this.updateStatus("Error checking notification status", "error")
    }
  }

  async toggleSubscription(event) {
    const isChecked = event.target.checked

    if (isChecked) {
      await this.subscribe()
    } else {
      await this.unsubscribe()
    }
  }

  async subscribe() {
    try {
      await subscribeToPush({ headers: this.fetchHeaders() })
      this.subscribedValue = true
      this.updateToggleState()
      this.syncWeeklyPreferenceUi(true)
      if (this.hasWeeklyToggleTarget) this.weeklyToggleTarget.checked = true
      this.updateStatus("✓ Notifications enabled", "enabled")
    } catch (error) {
      console.error("Error subscribing to push notifications:", error)
      this.updateStatus(`Failed to enable notifications: ${error.message}`, "error")
      this.toggleTarget.checked = false
      this.syncWeeklyPreferenceUi(false)
    }
  }

  async unsubscribe() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      if (subscription) {
        const endpoint = subscription.endpoint

        await subscription.unsubscribe()

        await fetch("/push_subscription", {
          method: "DELETE",
          headers: this.fetchHeaders(),
          body: JSON.stringify({ endpoint })
        })

        this.subscribedValue = false
        this.updateToggleState()
        this.syncWeeklyPreferenceUi(false)
        this.updateStatus("Notifications disabled", "disabled")
      }
    } catch (error) {
      console.error("Error unsubscribing from push notifications:", error)
      this.updateStatus(`Failed to disable notifications: ${error.message}`, "error")
      this.toggleTarget.checked = true
      this.syncWeeklyPreferenceUi(true)
    }
  }

  updateToggleState() {
    if (!this.hasToggleTarget) return
    this.toggleTarget.checked = this.subscribedValue
  }

  syncWeeklyPreferenceUi(subscribed) {
    if (this.hasWeeklyWrapTarget) {
      this.weeklyWrapTarget.classList.toggle("is-hidden", !subscribed)
    }

    if (this.hasWeeklyToggleTarget && !subscribed) {
      this.weeklyToggleTarget.checked = false
    }
  }

  updateStatus(message, state = null) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.classList.remove("enabled", "disabled", "error")

      if (state) {
        this.statusTarget.classList.add(state)
      }
    }
  }

  disableToggle() {
    if (!this.hasToggleTarget) return
    this.toggleTarget.disabled = true
    this.toggleTarget.checked = false
  }

  fetchHeaders() {
    const headers = {
      "Content-Type": "application/json"
    }

    const csrfToken = this.getCsrfToken()
    if (csrfToken) {
      headers["X-CSRF-Token"] = csrfToken
    }

    return headers
  }

  getCsrfToken() {
    const token = document.querySelector("[name='csrf-token']")
    if (!token) {
      console.warn("CSRF token not found in page")
      return null
    }
    return token.content
  }
}
