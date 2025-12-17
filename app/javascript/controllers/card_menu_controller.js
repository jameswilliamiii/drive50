import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="card-menu"
export default class extends Controller {
  static targets = ["menu", "button", "backdrop"]

  toggle(event) {
    event.stopPropagation()
    const isOpen = this.menuTarget.classList.contains("card-menu-open")

    if (isOpen) {
      this.close()
    } else {
      // Close any other open menus first
      document.querySelectorAll(".card-menu-open").forEach(menu => {
        if (menu !== this.menuTarget) {
          menu.classList.remove("card-menu-open")
        }
      })
      document.querySelectorAll(".card-menu-backdrop").forEach(backdrop => {
        if (backdrop !== this.backdropTarget) {
          backdrop.classList.remove("card-menu-backdrop-visible")
        }
      })
      this.open()
    }
  }

  open() {
    // Prevent body scroll when menu is open
    document.body.style.overflow = "hidden"
    this.backdropTarget.classList.add("card-menu-backdrop-visible")
    this.menuTarget.classList.add("card-menu-open")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    document.body.style.overflow = ""
    this.backdropTarget.classList.remove("card-menu-backdrop-visible")
    this.menuTarget.classList.remove("card-menu-open")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  // Handle backdrop click
  handleBackdropClick(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  // Close menu when clicking on a menu item
  handleMenuItemClick(event) {
    // Don't close immediately if it's a delete button (let confirmation happen)
    if (!event.target.closest("button[data-turbo-confirm]")) {
      setTimeout(() => this.close(), 100)
    }
  }

  // Handle form submission - close menu and restore scroll
  handleFormSubmit(event) {
    // Close the menu when form is submitted (including delete)
    this.close()
  }

  // Cleanup when element is removed from DOM
  disconnect() {
    // Ensure scroll is restored if controller is disconnected
    document.body.style.overflow = ""
  }
}

