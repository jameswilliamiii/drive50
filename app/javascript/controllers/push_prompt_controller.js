import { Controller } from "@hotwired/stimulus"
import { lockScroll, unlockScroll } from "helpers/scroll_lock"
import { iosNeedsHomeScreenInstall, isPushSupported, subscribeToPush } from "push_subscribe"

const DISMISS_KEY = "drive50.pushPromptDismissed"

export default class extends Controller {
  static targets = ["enable", "iosNote", "status"]

  async connect() {
    // Same Turbo cache ghost as drive/day modals: snapshot can keep `open`
    // without top-layer membership. Clear before any early return.
    this.resetRestoredDialog()

    if (document.body.dataset.offerPushPrompt !== "true") return
    if (!isPushSupported()) return

    const iosNeedsInstall = iosNeedsHomeScreenInstall()
    if (iosNeedsInstall) {
      this.showIosGuidance()
    }

    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()
      if (subscription) return
    } catch (error) {
      console.error("Error checking push subscription:", error)
      return
    }

    if (localStorage.getItem(DISMISS_KEY)) return

    this.show()
  }

  resetRestoredDialog() {
    this.element.classList.add("is-restoring")
    this.element.removeAttribute("open")
    getComputedStyle(this.element).opacity
    this.element.classList.remove("is-restoring")
    unlockScroll(this)
  }

  disconnect() {
    unlockScroll(this)
  }

  async enable(event) {
    if (iosNeedsHomeScreenInstall()) return

    const button = event.currentTarget
    const originalText = button.textContent
    button.disabled = true
    button.textContent = "Enabling..."

    try {
      await subscribeToPush()
      this.hide()
    } catch (error) {
      console.error("Error enabling push notifications:", error)
      button.disabled = false
      button.textContent = originalText
      this.showStatus(error.message || "Failed to enable notifications")
    }
  }

  dismiss() {
    localStorage.setItem(DISMISS_KEY, "1")
    this.hide()
  }

  backdropClick(event) {
    if (event.target === this.element) this.dismiss()
  }

  showIosGuidance() {
    if (this.hasIosNoteTarget) {
      this.iosNoteTarget.style.display = "block"
    }
    if (this.hasEnableTarget) {
      this.enableTarget.disabled = true
      this.enableTarget.hidden = true
    }
  }

  show() {
    this.element.classList.remove("hidden")
    if (this.element.matches(":modal")) return

    this.element.removeAttribute("open")
    lockScroll(this)
    this.element.showModal()
  }

  hide() {
    unlockScroll(this)
    if (typeof this.element.close === "function") {
      this.element.close()
    }
    this.element.classList.add("hidden")
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.hidden = false
    this.statusTarget.textContent = message
    this.statusTarget.classList.add("error")
  }
}
