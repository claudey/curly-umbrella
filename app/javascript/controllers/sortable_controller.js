import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = { 
    handle: String,
    axis: String, // 'x', 'y', or 'both'
    updateUrl: String,
    csrfToken: String
  }

  connect() {
    this.setupSortable()
    this.draggedElement = null
    this.placeholder = null
  }

  setupSortable() {
    this.itemTargets.forEach(item => {
      item.draggable = true
      item.addEventListener('dragstart', this.handleDragStart.bind(this))
      item.addEventListener('dragover', this.handleDragOver.bind(this))
      item.addEventListener('drop', this.handleDrop.bind(this))
      item.addEventListener('dragend', this.handleDragEnd.bind(this))
    })
  }

  handleDragStart(event) {
    this.draggedElement = event.target.closest('[data-sortable-target="item"]')
    
    if (this.hasHandleValue) {
      const handle = event.target.closest(this.handleValue)
      if (!handle) {
        event.preventDefault()
        return
      }
    }

    this.draggedElement.classList.add('dragging')
    this.createPlaceholder()
    
    // Store the original index
    this.originalIndex = Array.from(this.itemTargets).indexOf(this.draggedElement)
    
    // Set drag data
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', this.draggedElement.outerHTML)
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    
    const afterElement = this.getDragAfterElement(event.clientY)
    
    if (afterElement == null) {
      this.element.appendChild(this.placeholder)
    } else {
      this.element.insertBefore(this.placeholder, afterElement)
    }
  }

  handleDrop(event) {
    event.preventDefault()
    
    if (this.draggedElement && this.placeholder) {
      // Insert the dragged element before the placeholder
      this.element.insertBefore(this.draggedElement, this.placeholder)
      
      // Get new position
      const newIndex = Array.from(this.itemTargets).indexOf(this.draggedElement)
      
      if (newIndex !== this.originalIndex) {
        this.updateOrder(newIndex)
      }
    }
  }

  handleDragEnd(event) {
    if (this.draggedElement) {
      this.draggedElement.classList.remove('dragging')
    }
    
    if (this.placeholder && this.placeholder.parentNode) {
      this.placeholder.parentNode.removeChild(this.placeholder)
    }
    
    this.draggedElement = null
    this.placeholder = null
  }

  createPlaceholder() {
    this.placeholder = document.createElement('div')
    this.placeholder.className = 'sortable-placeholder border-2 border-dashed border-primary bg-primary/10 rounded-lg'
    this.placeholder.style.height = this.draggedElement.offsetHeight + 'px'
    this.placeholder.style.margin = getComputedStyle(this.draggedElement).margin
  }

  getDragAfterElement(y) {
    const draggableElements = [...this.itemTargets].filter(item => 
      item !== this.draggedElement && !item.classList.contains('dragging')
    )

    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2

      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child }
      } else {
        return closest
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  updateOrder(newIndex) {
    if (!this.hasUpdateUrlValue) return
    
    const itemId = this.draggedElement.dataset.id
    
    const data = {
      id: itemId,
      position: newIndex,
      authenticity_token: this.csrfTokenValue || document.querySelector('meta[name="csrf-token"]')?.content
    }

    fetch(this.updateUrlValue, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify(data)
    })
    .then(response => {
      if (!response.ok) {
        throw new Error('Network response was not ok')
      }
      return response.json()
    })
    .then(data => {
      this.showSuccess('Order updated successfully')
      
      // Update positions in DOM
      this.updatePositionNumbers()
    })
    .catch(error => {
      console.error('Error updating order:', error)
      this.showError('Failed to update order')
      
      // Revert to original position
      this.revertOrder()
    })
  }

  updatePositionNumbers() {
    this.itemTargets.forEach((item, index) => {
      const positionElement = item.querySelector('.position-number')
      if (positionElement) {
        positionElement.textContent = index + 1
      }
    })
  }

  revertOrder() {
    // Move the dragged element back to its original position
    const currentItems = Array.from(this.itemTargets)
    const targetPosition = currentItems[this.originalIndex]
    
    if (targetPosition) {
      this.element.insertBefore(this.draggedElement, targetPosition)
    } else {
      this.element.appendChild(this.draggedElement)
    }
  }

  showSuccess(message) {
    this.showToast(message, 'success')
  }

  showError(message) {
    this.showToast(message, 'error')
  }

  showToast(message, type) {
    const toast = document.createElement('div')
    toast.className = 'toast toast-top toast-end'
    toast.innerHTML = `
      <div class="alert alert-${type}">
        <i class="ph ph-${type === 'success' ? 'check-circle' : 'warning-circle'}"></i>
        <span>${message}</span>
      </div>
    `
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      toast.remove()
    }, 3000)
  }

  // Public method to add new sortable items
  itemTargetConnected(element) {
    element.draggable = true
    element.addEventListener('dragstart', this.handleDragStart.bind(this))
    element.addEventListener('dragover', this.handleDragOver.bind(this))
    element.addEventListener('drop', this.handleDrop.bind(this))
    element.addEventListener('dragend', this.handleDragEnd.bind(this))
  }
}