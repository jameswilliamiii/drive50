import { Controller } from "@hotwired/stimulus"
import { lockScroll, unlockScroll } from "helpers/scroll_lock"

// Connects to data-controller="card-menu"
export default class extends Controller {
  static targets = ["menu", "button", "backdrop"]

  connect() {
    // Ensure menu is closed and hidden when page loads
    this.close()
    this.hide()

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
    this.hide()
  }

  toggle(event) {
    event.stopPropagation()
    const isOpen = this.menuTarget.classList.contains("card-menu-open")

    if (isOpen) {
      this.close()
    } else {
      // Close any other open menus through their own controllers. Stripping the
      // class by hand skips their close(), which is where they hand back their
      // claim on the shared scroll lock — an orphaned claim keeps the page
      // unscrollable with nothing on screen, since the lock is reference counted.
      document.querySelectorAll(".card-menu-open").forEach(menu => {
        if (menu === this.menuTarget) return

        const element = menu.closest("[data-controller~='card-menu']")
        const controller = element &&
          this.application.getControllerForElementAndIdentifier(element, "card-menu")

        controller ? controller.close() : menu.classList.remove("card-menu-open")
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
    // Remove hidden class before opening
    this.show()
    // Lock body scroll only for the mobile bottom-sheet; the desktop dropdown is
    // a small anchored popover and must not freeze the page behind it.
    if (window.matchMedia("(max-width: 768px)").matches) {
      lockScroll(this)
    }
    this.backdropTarget.classList.add("card-menu-backdrop-visible")
    this.menuTarget.classList.add("card-menu-open")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    // Unconditionally, before the open check: toggle() strips .card-menu-open off
    // other menus directly, so those instances reach close() already looking shut
    // and would never release the claim they took — leaving the page locked with
    // nothing on screen. Releasing a claim you never took is a no-op by design.
    unlockScroll(this)

    // Only close if this menu is actually open
    if (this.hasMenuTarget && this.menuTarget.classList.contains("card-menu-open")) {
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.remove("card-menu-backdrop-visible")
      }
      this.menuTarget.classList.remove("card-menu-open")
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute("aria-expanded", "false")
      }
    }
    // Always hide the menu when closing to prevent flash
    this.hide()
  }

  hide() {
    this.menuTarget.classList.add("hidden")
  }

  show() {
    this.menuTarget.classList.remove("hidden")
  }

  // Close all card menus on the page
  closeAllMenus() {
    // Release every holder, not just this one: see toggle().
    unlockScroll(this)
    document.querySelectorAll(".card-menu-open").forEach(menu => {
      const element = menu.closest("[data-controller~='card-menu']")
      const controller = element &&
        this.application.getControllerForElementAndIdentifier(element, "card-menu")
      if (controller && controller !== this) controller.close()

      menu.classList.remove("card-menu-open")
      menu.classList.add("hidden")
    })
    document.querySelectorAll(".card-menu-backdrop-visible").forEach(backdrop => {
      backdrop.classList.remove("card-menu-backdrop-visible")
    })
    document.querySelectorAll("[data-card-menu-target='button'][aria-expanded='true']").forEach(button => {
      button.setAttribute("aria-expanded", "false")
    })
    unlockScroll(this)
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

