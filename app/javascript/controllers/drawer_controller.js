import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer"
export default class extends Controller {
  static targets = ["drawer", "button", "backdrop"]

  get drawers() {
    return this.drawerTargets
  }

  get backdrops() {
    return this.backdropTargets
  }

  toggle() {
    const isOpen = this.drawers.some(drawer => drawer.classList.contains("drawer-open"))

    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  get visibleButton() {
    // Find the visible button (on mobile, it's in bottom nav; on desktop, it's in header)
    return this.buttonTargets.find(button => {
      const style = window.getComputedStyle(button)
      return style.display !== 'none' && style.visibility !== 'hidden'
    }) || this.buttonTargets[0]
  }

  open() {
    // Prevent body scroll when drawer is open (only on mobile)
    if (window.innerWidth < 769) {
      document.body.style.overflow = "hidden"
    }

    // Show all backdrops
    this.backdrops.forEach(backdrop => {
      backdrop.classList.add("drawer-backdrop-visible")
    })

    // Open all drawers
    this.drawers.forEach(drawer => {
      drawer.classList.add("drawer-open")
    })

    const button = this.visibleButton
    if (button) {
      button.classList.add("menu-button-active")
      button.setAttribute("aria-expanded", "true")
    }
  }

  close() {
    document.body.style.overflow = ""

    // Hide all backdrops
    this.backdrops.forEach(backdrop => {
      backdrop.classList.remove("drawer-backdrop-visible")
    })

    // Close all drawers
    this.drawers.forEach(drawer => {
      drawer.classList.remove("drawer-open")
    })

    const button = this.visibleButton
    if (button) {
      button.classList.remove("menu-button-active")
      button.setAttribute("aria-expanded", "false")
    }
  }

  // Handle clicks outside the drawer
  handleClickOutside(event) {
    const isOpen = this.drawers.some(drawer => drawer.classList.contains("drawer-open"))
    if (!isOpen) return

    const clickedInsideDrawer = this.drawers.some(drawer => drawer.contains(event.target))
    const clickedInsideButton = this.buttonTargets.some(button => button.contains(event.target))

    // Don't close if clicking on the button or inside a drawer
    if (clickedInsideButton || clickedInsideDrawer) return

    // Close if clicking outside
    this.close()
  }

  // Handle backdrop click
  handleBackdropClick(event) {
    if (this.backdrops.includes(event.target)) {
      this.close()
    }
  }

  // Close drawer when clicking on a menu item
  handleMenuItemClick(event) {
    // Don't close immediately if it's a delete button (let confirmation happen)
    if (!event.target.closest("a[data-method='delete']")) {
      setTimeout(() => this.close(), 100)
    }
  }
}

