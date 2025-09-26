import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    content: String,
    position: { type: String, default: "top" },
    delay: { type: Number, default: 500 }
  }

  connect() {
    this.tooltip = null
    this.timeout = null
    
    // Use title attribute if no content value is provided
    if (!this.contentValue && this.element.title) {
      this.contentValue = this.element.title
      this.element.removeAttribute("title")
    }
    
    // Add DaisyUI tooltip classes
    this.element.classList.add("tooltip")
    this.element.classList.add(`tooltip-${this.positionValue}`)
    this.element.setAttribute("data-tip", this.contentValue)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // For custom tooltip implementation if needed
  show() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    
    this.timeout = setTimeout(() => {
      this.element.classList.add("tooltip-open")
    }, this.delayValue)
  }

  hide() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    
    this.element.classList.remove("tooltip-open")
  }

  mouseenter() {
    this.show()
  }

  mouseleave() {
    this.hide()
  }

  focusin() {
    this.show()
  }

  focusout() {
    this.hide()
  }
}