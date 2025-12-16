import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="infinite-scroll"
// Automatically loads more content when the link comes into view
export default class extends Controller {
  static targets = ["link"]

  connect() {
    if (!this.hasLinkTarget) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && this.linkTarget && !this.isLoading) {
          this.load()
        }
      })
    }, {
      rootMargin: "300px"
    })

    this.observer.observe(this.linkTarget)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  get isLoading() {
    return this.linkTarget?.dataset.loading === "true"
  }

  load() {
    if (!this.linkTarget) return

    this.linkTarget.dataset.loading = "true"
    // Turbo will handle the navigation automatically
    this.linkTarget.click()
  }
}
