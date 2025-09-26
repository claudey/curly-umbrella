import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "header", "body", "footer"]
  static values = { 
    title: String,
    size: String,
    type: String,
    removable: { type: Boolean, default: true },
    collapsible: { type: Boolean, default: false },
    expanded: { type: Boolean, default: true }
  }

  connect() {
    this.setupWidget()
    this.updateExpandedState()
  }

  setupWidget() {
    // Add DaisyUI classes based on widget configuration
    if (!this.element.classList.contains('card')) {
      this.element.classList.add('card', 'bg-base-100', 'shadow-lg', 'border')
    }
    
    // Add size-specific classes
    this.applySize()
    
    // Setup collapsible behavior if enabled
    if (this.collapsibleValue) {
      this.element.classList.add('collapse')
      this.updateExpandedState()
    }
  }

  applySize() {
    // Remove existing size classes
    this.element.classList.remove('card-compact', 'card-normal', 'card-side')
    
    switch (this.sizeValue) {
      case 'xs':
      case 'sm':
        this.element.classList.add('card-compact')
        break
      case 'lg':
      case 'xl':
        this.element.classList.add('card-normal')
        break
      default:
        this.element.classList.add('card-normal')
    }
  }

  remove(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    if (!this.removableValue) {
      console.warn('Widget is not removable')
      return
    }

    // Confirm removal
    if (!confirm('Are you sure you want to remove this widget?')) {
      return
    }

    // Animate out
    this.element.style.transition = 'all 0.3s ease'
    this.element.style.transform = 'scale(0.8) translateY(-20px)'
    this.element.style.opacity = '0'

    setTimeout(() => {
      // Dispatch removal event before removing element
      this.dispatch('removed', {
        detail: {
          widgetId: this.element.dataset.widgetId,
          type: this.typeValue,
          element: this.element
        },
        bubbles: true
      })

      // Remove element
      this.element.remove()
    }, 300)
  }

  toggle(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    if (!this.collapsibleValue) return

    this.expandedValue = !this.expandedValue
    this.updateExpandedState()

    this.dispatch('toggled', {
      detail: {
        widgetId: this.element.dataset.widgetId,
        expanded: this.expandedValue,
        element: this.element
      },
      bubbles: true
    })
  }

  updateExpandedState() {
    if (!this.collapsibleValue) return

    if (this.expandedValue) {
      this.element.classList.remove('collapse-close')
      this.element.classList.add('collapse-open')
    } else {
      this.element.classList.remove('collapse-open')
      this.element.classList.add('collapse-close')
    }

    // Update toggle button icon if it exists
    const toggleBtn = this.element.querySelector('[data-action*="toggle"]')
    if (toggleBtn) {
      const icon = toggleBtn.querySelector('svg')
      if (icon) {
        icon.style.transform = this.expandedValue ? 'rotate(180deg)' : 'rotate(0deg)'
      }
    }
  }

  refresh(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    // Add loading state
    this.element.classList.add('loading')
    
    // Dispatch refresh event
    this.dispatch('refresh', {
      detail: {
        widgetId: this.element.dataset.widgetId,
        type: this.typeValue,
        element: this.element
      },
      bubbles: true
    })

    // Simulate refresh completion (in real app, this would be handled by the response)
    setTimeout(() => {
      this.element.classList.remove('loading')
    }, 1000)
  }

  resize(newSize) {
    this.sizeValue = newSize
    this.applySize()
    
    this.dispatch('resized', {
      detail: {
        widgetId: this.element.dataset.widgetId,
        size: newSize,
        element: this.element
      },
      bubbles: true
    })
  }

  updateContent(html) {
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = html
    } else if (this.hasBodyTarget) {
      this.bodyTarget.innerHTML = html
    } else {
      // Find the card-body element
      const cardBody = this.element.querySelector('.card-body')
      if (cardBody) {
        cardBody.innerHTML = html
      }
    }

    this.dispatch('contentUpdated', {
      detail: {
        widgetId: this.element.dataset.widgetId,
        element: this.element
      },
      bubbles: true
    })
  }

  highlight() {
    this.element.classList.add('ring-2', 'ring-primary', 'ring-opacity-50')
    setTimeout(() => {
      this.element.classList.remove('ring-2', 'ring-primary', 'ring-opacity-50')
    }, 2000)
  }

  // Handle widget-specific actions based on type
  handleAction(event) {
    const action = event.params.action
    
    switch (action) {
      case 'edit':
        this.editWidget()
        break
      case 'clone':
        this.cloneWidget()
        break
      case 'export':
        this.exportWidget()
        break
      default:
        console.log(`Unknown widget action: ${action}`)
    }
  }

  editWidget() {
    // Dispatch edit event for parent components to handle
    this.dispatch('edit', {
      detail: {
        widgetId: this.element.dataset.widgetId,
        type: this.typeValue,
        title: this.titleValue,
        size: this.sizeValue,
        element: this.element
      },
      bubbles: true
    })
  }

  cloneWidget() {
    this.dispatch('clone', {
      detail: {
        widgetId: this.element.dataset.widgetId,
        type: this.typeValue,
        title: this.titleValue,
        size: this.sizeValue,
        element: this.element
      },
      bubbles: true
    })
  }

  exportWidget() {
    const widgetData = {
      id: this.element.dataset.widgetId,
      type: this.typeValue,
      title: this.titleValue,
      size: this.sizeValue,
      collapsible: this.collapsibleValue,
      expanded: this.expandedValue,
      timestamp: new Date().toISOString()
    }

    const dataStr = JSON.stringify(widgetData, null, 2)
    const dataBlob = new Blob([dataStr], { type: 'application/json' })
    
    const link = document.createElement('a')
    link.href = URL.createObjectURL(dataBlob)
    link.download = `widget-${this.typeValue}-${Date.now()}.json`
    link.click()
  }
}