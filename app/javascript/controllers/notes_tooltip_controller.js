import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "trigger"]

  connect() {
    this.checkTruncation()
  }

  checkTruncation() {
    const isTruncated = this.textTarget.scrollWidth > this.textTarget.clientWidth
    this.triggerTarget.classList.toggle("show-tooltip", isTruncated)
  }
}
