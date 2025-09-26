import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]
  static values = { expanded: Boolean }

  connect() {
    this.updateIcon()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    
    if (this.expandedValue) {
      this.element.classList.remove("collapse-close")
      this.element.classList.add("collapse-open")
    } else {
      this.element.classList.remove("collapse-open")
      this.element.classList.add("collapse-close")
    }
    
    this.updateIcon()
    
    // Dispatch custom event for other components to listen to
    this.dispatch("toggled", { 
      detail: { 
        expanded: this.expandedValue,
        card: this.element 
      } 
    })
  }

  updateIcon() {
    if (this.hasIconTarget) {
      const rotation = this.expandedValue ? "rotate-180" : ""
      this.iconTarget.style.transform = this.expandedValue ? "rotate(180deg)" : "rotate(0deg)"
    }
  }

  expandedValueChanged() {
    this.updateIcon()
  }
}