import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toast"
export default class extends Controller {
  static values = {
    type: String,
    duration: { type: Number, default: 5000 }
  }

  connect() {
    // Show toast with animation
    this.show()

    // Auto-dismiss after duration
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.durationValue)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  show() {
    // Trigger animation by adding show class
    requestAnimationFrame(() => {
      this.element.classList.add("toast-show")
    })
  }

  dismiss() {
    // Remove show class to trigger exit animation
    this.element.classList.remove("toast-show")
    this.element.classList.add("toast-hide")

    // Remove from DOM after animation
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  close(event) {
    event.preventDefault()
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    this.dismiss()
  }
}

