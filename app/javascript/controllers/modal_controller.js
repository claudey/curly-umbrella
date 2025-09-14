import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "dialog"]
  static classes = ["open"]

  connect() {
    this.close()
  }

  open() {
    this.element.classList.add(...this.openClasses)
    this.element.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Focus on the modal for accessibility
    this.dialogTarget.focus()
    
    // Add event listener for escape key
    this.escapeListener = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escapeListener)
    
    // Dispatch custom event
    this.dispatch("opened")
  }

  close() {
    this.element.classList.remove(...this.openClasses)
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    
    // Remove escape key listener
    if (this.escapeListener) {
      document.removeEventListener("keydown", this.escapeListener)
    }
    
    // Dispatch custom event
    this.dispatch("closed")
    
    // Hide modal after animation
    setTimeout(() => {
      this.element.classList.add("hidden")
    }, 200)
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  clickOutside(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  isOpen() {
    return this.element.classList.contains(this.openClasses[0])
  }

  disconnect() {
    if (this.escapeListener) {
      document.removeEventListener("keydown", this.escapeListener)
    }
    document.body.classList.remove("overflow-hidden")
  }
}