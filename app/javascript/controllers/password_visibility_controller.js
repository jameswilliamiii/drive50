import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-visibility"
// Toggles a password field between masked and visible, swapping the eye icon.
export default class extends Controller {
  static targets = ["input", "show", "hide", "button"]

  toggle() {
    const reveal = this.inputTarget.type === "password"
    this.inputTarget.type = reveal ? "text" : "password"
    this.showTarget.classList.toggle("hidden", reveal)
    this.hideTarget.classList.toggle("hidden", !reveal)
    this.buttonTarget.setAttribute("aria-label", reveal ? "Hide password" : "Show password")
  }
}
