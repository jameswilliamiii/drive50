import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "content"]

  toggle() {
    const isExpanded = this.buttonTarget.getAttribute("aria-expanded") === "true"

    if (isExpanded) {
      this.collapse()
    } else {
      this.expand()
    }
  }

  expand() {
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.contentTarget.classList.add("expanded")
  }

  collapse() {
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.contentTarget.classList.remove("expanded")
  }
}
