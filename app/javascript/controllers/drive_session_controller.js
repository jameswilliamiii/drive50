import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drive-session"
// Handles fade-out animation when deleting a drive session row
export default class extends Controller {
  static values = {
    animationDuration: { type: Number, default: 300 }
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

    // Wait for animation to complete, then submit
    setTimeout(() => {
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

      // Ensure body scroll is restored before submitting (in case card menu is open)
      document.body.style.overflow = ""

      // Submit form programmatically (confirmation already handled)
      form.requestSubmit()
    }, this.animationDurationValue)
  }

  // Cleanup when element is removed from DOM
  disconnect() {
    // Ensure scroll is restored if controller is disconnected
    document.body.style.overflow = ""
  }
}

