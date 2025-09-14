import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay", "toggle"]
  static classes = ["open"]

  connect() {
    this.close()
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.sidebarTarget.classList.add(...this.openClasses)
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Add event listener for escape key
    this.escapeListener = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escapeListener)
  }

  close() {
    this.sidebarTarget.classList.remove(...this.openClasses)
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    
    // Remove escape key listener
    if (this.escapeListener) {
      document.removeEventListener("keydown", this.escapeListener)
    }
  }

  clickOutside(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  isOpen() {
    return this.sidebarTarget.classList.contains(this.openClasses[0])
  }

  disconnect() {
    if (this.escapeListener) {
      document.removeEventListener("keydown", this.escapeListener)
    }
  }
}