import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="card-menu"
export default class extends Controller {
  static targets = ["menu", "button", "backdrop"]

  connect() {
    // Close this menu when page is loaded or restored from cache
    this.close()

    // Listen for Turbo navigation events to close all menus
    this.boundCloseAllMenus = this.closeAllMenus.bind(this)
    document.addEventListener("turbo:before-visit", this.boundCloseAllMenus)
    document.addEventListener("turbo:load", this.boundCloseAllMenus)
    document.addEventListener("turbo:restore", this.boundCloseAllMenus)
  }

  disconnect() {
    // Remove event listeners
    document.removeEventListener("turbo:before-visit", this.boundCloseAllMenus)
    document.removeEventListener("turbo:load", this.boundCloseAllMenus)
    document.removeEventListener("turbo:restore", this.boundCloseAllMenus)

    // Ensure scroll is restored if controller is disconnected
    this.close()
  }

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
    // Only close if this menu is actually open
    if (this.hasMenuTarget && this.menuTarget.classList.contains("card-menu-open")) {
      document.body.style.overflow = ""
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.remove("card-menu-backdrop-visible")
      }
      this.menuTarget.classList.remove("card-menu-open")
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute("aria-expanded", "false")
      }
    }
  }

  // Close all card menus on the page
  closeAllMenus() {
    document.querySelectorAll(".card-menu-open").forEach(menu => {
      menu.classList.remove("card-menu-open")
    })
    document.querySelectorAll(".card-menu-backdrop-visible").forEach(backdrop => {
      backdrop.classList.remove("card-menu-backdrop-visible")
    })
    document.querySelectorAll("[data-card-menu-target='button'][aria-expanded='true']").forEach(button => {
      button.setAttribute("aria-expanded", "false")
    })
    document.body.style.overflow = ""
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
}

