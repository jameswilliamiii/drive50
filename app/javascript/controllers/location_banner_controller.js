import { Controller } from "@hotwired/stimulus"

const DISMISS_KEY = "drive50.locationBannerDismissed"

export default class extends Controller {
  connect() {
    if (localStorage.getItem(DISMISS_KEY)) this.hide()
  }

  dismiss() {
    localStorage.setItem(DISMISS_KEY, "1")
    this.hide()
  }

  hide() {
    this.element.classList.add("hidden")
  }
}
