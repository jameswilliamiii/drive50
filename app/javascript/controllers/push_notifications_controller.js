import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "status", "iosNote", "toggleLabel"]
  static values = {
    subscribed: Boolean
  }

  async connect() {
    // Check if push notifications are supported
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.updateStatus("Push notifications are not supported in this browser", "error")
      this.disableToggle()
      return
    }

    // Show iOS note if on iOS and not in standalone mode
    const iosNeedsInstall = this.showIosNoteIfNeeded()

    // Disable toggle on iOS if not in standalone mode
    if (iosNeedsInstall) {
      this.updateStatus("Install app to home screen to enable notifications", "error")
      this.disableToggle()
      return
    }

    // Check current subscription status
    await this.checkSubscription()
  }

  showIosNoteIfNeeded() {
    if (!this.hasIosNoteTarget) return false

    // Detect iOS devices
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream

    if (isIOS) {
      // Check if running in standalone mode (installed to home screen)
      const isStandalone = window.navigator.standalone || window.matchMedia('(display-mode: standalone)').matches

      // Only show note if NOT in standalone mode (they need to install it)
      if (!isStandalone) {
        this.iosNoteTarget.style.display = 'block'
        return true // iOS needs installation
      }
    }

    return false // Not iOS or already installed
  }

  async checkSubscription() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      this.subscribedValue = !!subscription
      this.updateToggleState()

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
      // Request notification permission
      const permission = await Notification.requestPermission()

      if (permission !== "granted") {
        this.updateStatus("Notification permission denied", "error")
        this.toggleTarget.checked = false
        return
      }

      // Get VAPID public key from server
      const response = await fetch("/push_subscription/new")
      const { public_key } = await response.json()

      // Subscribe to push notifications
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(public_key)
      })

      // Send subscription to server
      const subscriptionData = subscription.toJSON()
      const saveResponse = await fetch("/push_subscription", {
        method: "POST",
        headers: this.fetchHeaders(),
        body: JSON.stringify({ subscription: subscriptionData })
      })

      if (saveResponse.ok) {
        this.subscribedValue = true
        this.updateToggleState()
        this.updateStatus("✓ Notifications enabled", "enabled")
      } else {
        throw new Error("Failed to save subscription")
      }
    } catch (error) {
      console.error("Error subscribing to push notifications:", error)
      this.updateStatus(`Failed to enable notifications: ${error.message}`, "error")
      this.toggleTarget.checked = false
    }
  }

  async unsubscribe() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      if (subscription) {
        const endpoint = subscription.endpoint

        // Unsubscribe from push manager
        await subscription.unsubscribe()

        // Remove subscription from server
        await fetch("/push_subscription", {
          method: "DELETE",
          headers: this.fetchHeaders(),
          body: JSON.stringify({ endpoint })
        })

        this.subscribedValue = false
        this.updateToggleState()
        this.updateStatus("Notifications disabled", "disabled")
      }
    } catch (error) {
      console.error("Error unsubscribing from push notifications:", error)
      this.updateStatus(`Failed to disable notifications: ${error.message}`, "error")
      this.toggleTarget.checked = true
    }
  }

  updateToggleState() {
    if (!this.hasToggleTarget) return
    this.toggleTarget.checked = this.subscribedValue
  }

  updateStatus(message, state = null) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message

      // Remove all state classes
      this.statusTarget.classList.remove("enabled", "disabled", "error")

      // Add new state class if provided
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

  // Helper function to get fetch headers with CSRF token
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

  // Helper function to get CSRF token
  getCsrfToken() {
    const token = document.querySelector("[name='csrf-token']")
    if (!token) {
      console.warn("CSRF token not found in page")
      return null
    }
    return token.content
  }

  // Helper function to convert VAPID key
  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding)
      .replace(/\-/g, "+")
      .replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }
}
