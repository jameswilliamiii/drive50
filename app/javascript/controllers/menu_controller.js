import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="menu"
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.close()
  }

  toggle() {
    const isOpen = this.menuTarget.classList.contains("menu-open")

    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.add("menu-open")
    this.buttonTarget.classList.add("menu-button-active")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.classList.remove("menu-open")
    this.buttonTarget.classList.remove("menu-button-active")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  // Handle clicks outside the menu (using data-action="click@window->menu#close")
  handleClickOutside(event) {
    if (!this.element.contains(event.target) && this.menuTarget.classList.contains("menu-open")) {
      this.close()
    }
  }
}

