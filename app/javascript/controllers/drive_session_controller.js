import { Controller } from "@hotwired/stimulus"
import { motionDuration } from "helpers/motion"

// Connects to data-controller="drive-session"
// Handles fade-out animation when deleting a drive session row
export default class extends Controller {
  // A filling animation outranks the .fade-out transition and would keep doing so
  // forever, so the class comes off as soon as the entrance is done — which also
  // keeps it out of the Turbo snapshot, where it would replay on every restore.
  connect() {
    if (!this.element.classList.contains("is-entering")) return

    const clear = () => this.element.classList.remove("is-entering")
    this.element.addEventListener("animationend", clear, { once: true })
    // Reduced motion sets animation-name: none, so animationend never comes and
    // the class would ride into the Turbo snapshot.
    this.enteringTimer = setTimeout(clear, motionDuration("--duration-base", 200) + 50)
  }

  handleDelete(event) {
    // Only handle delete forms
    const form = event.currentTarget
    const methodInput = form.querySelector('input[name="_method"][value="delete"]')

    if (!methodInput || this.element.classList.contains("fade-out")) {
      return
    }

    // Check for Turbo confirmation attribute
    const confirmMessage = form.dataset.turboConfirm ||
                          form.querySelector('button[data-turbo-confirm]')?.dataset.turboConfirm ||
                          form.querySelector('input[data-turbo-confirm]')?.dataset.turboConfirm

    // If confirmation is required, show it first
    if (confirmMessage) {
      if (!confirm(confirmMessage)) {
        // User cancelled, don't proceed
        event.preventDefault()
        event.stopPropagation()
        return
      }
    }

    // Prevent immediate form submission to allow animation
    event.preventDefault()
    event.stopPropagation()

    // Start fade-out animation
    this.element.classList.add("fade-out")

    // Wait for animation to complete, then submit. The timer is owned so a Turbo
    // Stream replacing the drives table mid-animation cannot leave it to fire
    // against a detached form, where requestSubmit() silently does nothing and the
    // delete the user just confirmed never happens.
    this.deleteTimer = setTimeout(() => {
      if (!this.element.isConnected) return

      // Hide row before submitting to prevent flash
      this.element.style.display = "none"

      // Remove confirmation attribute so it doesn't ask again
      if (form.dataset.turboConfirm) {
        delete form.dataset.turboConfirm
      }
      const button = form.querySelector('button[data-turbo-confirm]')
      if (button && button.dataset.turboConfirm) {
        delete button.dataset.turboConfirm
      }

      // Submit form programmatically (confirmation already handled)
      form.requestSubmit()
    }, motionDuration("--duration-base", 200))
  }

  disconnect() {
    clearTimeout(this.deleteTimer)
    clearTimeout(this.enteringTimer)
  }
}

