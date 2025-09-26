import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    position: Object,
    widgetId: String,
    widgetType: String 
  }

  connect() {
    this.element.addEventListener('dragstart', this.handleDragStart.bind(this))
    this.element.addEventListener('dragend', this.handleDragEnd.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('dragstart', this.handleDragStart.bind(this))
    this.element.removeEventListener('dragend', this.handleDragEnd.bind(this))
  }

  handleDragStart(event) {
    // Store the widget data for the drop handler
    const dragData = {
      widgetId: this.widgetIdValue,
      widgetType: this.widgetTypeValue,
      position: this.positionValue,
      sourceElement: this.element
    }
    
    event.dataTransfer.setData('application/json', JSON.stringify(dragData))
    event.dataTransfer.effectAllowed = 'move'
    
    // Add visual feedback
    this.element.classList.add('opacity-50', 'transform', 'rotate-2')
    
    // Dispatch custom event
    this.dispatch('dragstart', { 
      detail: dragData
    })
  }

  handleDragEnd(event) {
    // Remove visual feedback
    this.element.classList.remove('opacity-50', 'transform', 'rotate-2')
    
    // Dispatch custom event
    this.dispatch('dragend', { 
      detail: { 
        widgetId: this.widgetIdValue,
        element: this.element
      }
    })
  }

  // Method to update widget position
  updatePosition(newPosition) {
    this.positionValue = newPosition
    
    // Dispatch position change event
    this.dispatch('positionChanged', {
      detail: {
        widgetId: this.widgetIdValue,
        position: newPosition
      }
    })
  }
}