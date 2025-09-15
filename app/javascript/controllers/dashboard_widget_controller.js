import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["widget", "header", "body", "content", "title", "toggleButton", "dragHandle", "resizeHandle"]
  static values = { 
    title: String,
    size: String,
    type: String,
    refreshUrl: String,
    autoRefresh: Number
  }

  connect() {
    this.collapsed = false
    this.setupAutoRefresh()
    this.setupDragAndDrop()
    this.setupResize()
    this.loadWidgetState()
  }

  disconnect() {
    this.clearAutoRefresh()
  }

  setupAutoRefresh() {
    if (this.hasAutoRefreshValue && this.autoRefreshValue > 0) {
      this.autoRefreshInterval = setInterval(() => {
        this.refresh()
      }, this.autoRefreshValue * 1000)
    }
  }

  clearAutoRefresh() {
    if (this.autoRefreshInterval) {
      clearInterval(this.autoRefreshInterval)
      this.autoRefreshInterval = null
    }
  }

  setupDragAndDrop() {
    if (this.hasDragHandleTarget) {
      this.widgetTarget.draggable = true
      
      this.widgetTarget.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', this.widgetTarget.id)
        e.dataTransfer.effectAllowed = 'move'
        this.widgetTarget.classList.add('opacity-50')
      })

      this.widgetTarget.addEventListener('dragend', () => {
        this.widgetTarget.classList.remove('opacity-50')
      })
    }
  }

  setupResize() {
    if (this.hasResizeHandleTarget) {
      let isResizing = false
      let startX, startY, startWidth, startHeight

      this.resizeHandleTarget.addEventListener('mousedown', (e) => {
        isResizing = true
        startX = e.clientX
        startY = e.clientY
        
        const rect = this.widgetTarget.getBoundingClientRect()
        startWidth = rect.width
        startHeight = rect.height
        
        document.addEventListener('mousemove', this.handleResize.bind(this))
        document.addEventListener('mouseup', this.stopResize.bind(this))
        
        e.preventDefault()
      })
    }
  }

  handleResize(e) {
    const deltaX = e.clientX - this.startX
    const deltaY = e.clientY - this.startY
    
    const newWidth = Math.max(200, this.startWidth + deltaX)
    const newHeight = Math.max(150, this.startHeight + deltaY)
    
    this.widgetTarget.style.width = `${newWidth}px`
    this.widgetTarget.style.height = `${newHeight}px`
  }

  stopResize() {
    document.removeEventListener('mousemove', this.handleResize.bind(this))
    document.removeEventListener('mouseup', this.stopResize.bind(this))
    
    this.saveWidgetState()
  }

  async refresh() {
    if (!this.hasRefreshUrlValue) return

    try {
      this.showLoading()
      
      const response = await fetch(this.refreshUrlValue, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const html = await response.text()
      this.contentTarget.innerHTML = html
      
      this.hideLoading()
      this.showSuccessIndicator()
      
    } catch (error) {
      console.error('Widget refresh failed:', error)
      this.showError(error.message)
    }
  }

  toggle() {
    this.collapsed = !this.collapsed
    
    if (this.collapsed) {
      this.bodyTarget.style.display = 'none'
      this.toggleButtonTarget.innerHTML = this.getIconHTML('plus')
      this.widgetTarget.classList.add('collapsed')
    } else {
      this.bodyTarget.style.display = 'block'
      this.toggleButtonTarget.innerHTML = this.getIconHTML('minus')
      this.widgetTarget.classList.remove('collapsed')
    }
    
    this.saveWidgetState()
    this.dispatch('toggled', { detail: { collapsed: this.collapsed } })
  }

  remove() {
    if (confirm('Are you sure you want to remove this widget?')) {
      this.widgetTarget.style.transform = 'scale(0)'
      this.widgetTarget.style.opacity = '0'
      this.widgetTarget.style.transition = 'all 0.3s ease'
      
      setTimeout(() => {
        this.widgetTarget.remove()
        this.dispatch('removed', { detail: { widgetId: this.widgetTarget.id } })
      }, 300)
      
      this.removeWidgetState()
    }
  }

  showLoading() {
    const loadingIndicator = document.createElement('div')
    loadingIndicator.className = 'absolute inset-0 bg-base-100/80 flex items-center justify-center z-10'
    loadingIndicator.innerHTML = '<span class="loading loading-spinner loading-lg"></span>'
    loadingIndicator.dataset.widgetLoading = 'true'
    
    this.contentTarget.style.position = 'relative'
    this.contentTarget.appendChild(loadingIndicator)
  }

  hideLoading() {
    const loadingIndicator = this.contentTarget.querySelector('[data-widget-loading]')
    if (loadingIndicator) {
      loadingIndicator.remove()
    }
  }

  showError(message) {
    this.hideLoading()
    
    const errorElement = document.createElement('div')
    errorElement.className = 'alert alert-error'
    errorElement.innerHTML = `
      <div class="flex-1">
        <div class="flex items-center gap-2">
          ${this.getIconHTML('exclamation-triangle')}
          <span>Failed to refresh: ${message}</span>
        </div>
      </div>
      <button class="btn btn-sm btn-ghost" onclick="this.parentElement.remove()">×</button>
    `
    
    this.contentTarget.insertBefore(errorElement, this.contentTarget.firstChild)
    
    // Auto-remove error after 5 seconds
    setTimeout(() => {
      if (errorElement.parentElement) {
        errorElement.remove()
      }
    }, 5000)
  }

  showSuccessIndicator() {
    const indicator = document.createElement('div')
    indicator.className = 'absolute top-2 right-2 text-success animate-ping'
    indicator.innerHTML = this.getIconHTML('check-circle')
    
    this.headerTarget.style.position = 'relative'
    this.headerTarget.appendChild(indicator)
    
    setTimeout(() => {
      indicator.remove()
    }, 2000)
  }

  saveWidgetState() {
    const state = {
      collapsed: this.collapsed,
      position: {
        x: this.widgetTarget.offsetLeft,
        y: this.widgetTarget.offsetTop
      },
      size: {
        width: this.widgetTarget.offsetWidth,
        height: this.widgetTarget.offsetHeight
      }
    }
    
    localStorage.setItem(`widget-${this.widgetTarget.id}`, JSON.stringify(state))
  }

  loadWidgetState() {
    const savedState = localStorage.getItem(`widget-${this.widgetTarget.id}`)
    if (!savedState) return
    
    try {
      const state = JSON.parse(savedState)
      
      if (state.collapsed && this.hasToggleButtonTarget) {
        this.collapsed = true
        this.bodyTarget.style.display = 'none'
        this.toggleButtonTarget.innerHTML = this.getIconHTML('plus')
        this.widgetTarget.classList.add('collapsed')
      }
      
      if (state.size && this.hasResizeHandleTarget) {
        this.widgetTarget.style.width = `${state.size.width}px`
        this.widgetTarget.style.height = `${state.size.height}px`
      }
      
    } catch (error) {
      console.error('Failed to load widget state:', error)
    }
  }

  removeWidgetState() {
    localStorage.removeItem(`widget-${this.widgetTarget.id}`)
  }

  getIconHTML(iconName) {
    const icons = {
      'plus': '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path></svg>',
      'minus': '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path></svg>',
      'check-circle': '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>',
      'exclamation-triangle': '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path></svg>'
    }
    
    return icons[iconName] || ''
  }

  // Public API for external control
  setTitle(newTitle) {
    this.titleTarget.textContent = newTitle
    this.titleValue = newTitle
  }

  setContent(html) {
    this.contentTarget.innerHTML = html
  }

  show() {
    this.widgetTarget.style.display = 'block'
  }

  hide() {
    this.widgetTarget.style.display = 'none'
  }

  resize(width, height) {
    this.widgetTarget.style.width = `${width}px`
    this.widgetTarget.style.height = `${height}px`
    this.saveWidgetState()
  }
}