import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "grid", "widgetCount", "emptyState", "dropZone", 
    "addWidgetModal", "editModeToggle", "editModeText"
  ]
  static values = { 
    columns: Number, 
    sortable: Boolean, 
    customizable: Boolean 
  }

  connect() {
    this.editMode = false
    this.widgets = []
    this.updateWidgetCount()
    this.loadDashboardState()
    this.checkEmptyState()
    
    // Listen for widget events
    this.element.addEventListener('dashboard-widget:removed', this.onWidgetRemoved.bind(this))
    this.element.addEventListener('dashboard-widget:toggled', this.onWidgetToggled.bind(this))
  }

  setColumns(event) {
    const columns = parseInt(event.currentTarget.dataset.columns)
    this.columnsValue = columns
    
    // Update grid classes
    this.updateGridColumns(columns)
    
    // Update active button
    this.updateColumnButtons(event.currentTarget)
    
    // Save state
    this.saveDashboardState()
  }

  updateGridColumns(columns) {
    // Remove existing column classes
    this.gridTarget.classList.remove(
      'lg:grid-cols-1', 'lg:grid-cols-2', 'lg:grid-cols-3', 'lg:grid-cols-4', 'lg:grid-cols-5', 'lg:grid-cols-6'
    )
    
    // Add new column class
    this.gridTarget.classList.add(`lg:grid-cols-${columns}`)
  }

  updateColumnButtons(activeButton) {
    // Remove active class from all column buttons
    const columnButtons = this.element.querySelectorAll('[data-columns]')
    columnButtons.forEach(btn => btn.classList.remove('btn-active'))
    
    // Add active class to clicked button
    activeButton.classList.add('btn-active')
  }

  addWidget(event) {
    const widgetType = event.currentTarget.dataset.widgetType
    const widgetTitle = event.currentTarget.dataset.widgetTitle
    
    this.createWidget({
      type: widgetType,
      title: widgetTitle,
      size: 'medium',
      removable: true,
      draggable: this.sortableValue
    })
  }

  createWidget(options) {
    const widget = document.createElement('div')
    widget.className = this.getWidgetClasses(options.size, options.type)
    widget.innerHTML = this.generateWidgetHTML(options)
    
    // Add to grid
    this.gridTarget.appendChild(widget)
    
    // Initialize widget controller
    this.application.start()
    
    // Update state
    this.widgets.push(options)
    this.updateWidgetCount()
    this.checkEmptyState()
    this.saveDashboardState()
    
    // Animate in
    widget.style.opacity = '0'
    widget.style.transform = 'scale(0.8)'
    
    requestAnimationFrame(() => {
      widget.style.transition = 'all 0.3s ease'
      widget.style.opacity = '1'
      widget.style.transform = 'scale(1)'
    })
  }

  generateWidgetHTML(options) {
    const widgetId = `widget-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    
    return `
      <div class="dashboard-widget card bg-base-100 shadow-sm" 
           data-controller="dashboard-widget"
           data-dashboard-widget-title-value="${options.title}"
           data-dashboard-widget-size-value="${options.size}"
           data-dashboard-widget-type-value="${options.type}"
           id="${widgetId}">
        
        <div class="card-header flex justify-between items-center p-4 border-b border-base-300">
          <div class="flex items-center gap-3">
            ${options.draggable ? '<div class="drag-handle cursor-move opacity-50 hover:opacity-100"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path></svg></div>' : ''}
            <h3 class="font-semibold text-lg">${options.title}</h3>
          </div>
          
          <div class="flex items-center gap-2">
            ${options.removable ? '<button class="btn btn-ghost btn-sm text-error" data-action="click->dashboard-widget#remove" title="Remove Widget"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg></button>' : ''}
          </div>
        </div>
        
        <div class="card-body p-4">
          <div data-dashboard-widget-target="content">
            ${this.generateWidgetContent(options.type)}
          </div>
        </div>
      </div>
    `
  }

  generateWidgetContent(type) {
    switch (type) {
      case 'metric':
        return `
          <div class="stat">
            <div class="stat-value text-primary">24</div>
            <div class="stat-title">Active Applications</div>
            <div class="stat-desc text-success">↗︎ 12% (this month)</div>
          </div>
        `
      case 'chart':
        return `
          <div class="h-48 bg-base-200 rounded flex items-center justify-center">
            <div class="text-center">
              <svg class="w-12 h-12 mx-auto mb-2 text-base-content/50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
              </svg>
              <div class="text-sm text-base-content/70">Chart will appear here</div>
            </div>
          </div>
        `
      case 'list':
        return `
          <div class="space-y-2">
            <div class="flex justify-between items-center p-2 hover:bg-base-200 rounded">
              <span class="text-sm">Recent Application #12345</span>
              <span class="text-xs text-base-content/60">2 min ago</span>
            </div>
            <div class="flex justify-between items-center p-2 hover:bg-base-200 rounded">
              <span class="text-sm">Quote Submitted #QT-789</span>
              <span class="text-xs text-base-content/60">5 min ago</span>
            </div>
            <div class="flex justify-between items-center p-2 hover:bg-base-200 rounded">
              <span class="text-sm">Policy Approved #POL-456</span>
              <span class="text-xs text-base-content/60">10 min ago</span>
            </div>
          </div>
        `
      case 'activity':
        return `
          <div class="space-y-3">
            <div class="flex items-start gap-3">
              <div class="w-2 h-2 bg-success rounded-full mt-2 flex-shrink-0"></div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium">New application received</div>
                <div class="text-xs text-base-content/60">John Doe submitted motor insurance application</div>
                <div class="text-xs text-base-content/50">Just now</div>
              </div>
            </div>
            <div class="flex items-start gap-3">
              <div class="w-2 h-2 bg-info rounded-full mt-2 flex-shrink-0"></div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium">Quote under review</div>
                <div class="text-xs text-base-content/60">Insurance company reviewing quote #QT-789</div>
                <div class="text-xs text-base-content/50">5 minutes ago</div>
              </div>
            </div>
          </div>
        `
      default:
        return '<div class="text-center py-8 text-base-content/50">Widget content will appear here</div>'
    }
  }

  getWidgetClasses(size, type) {
    let classes = ''
    
    switch (size) {
      case 'small':
        classes = 'col-span-1 row-span-1'
        break
      case 'large':
        classes = 'col-span-2 row-span-2'
        break
      case 'full':
        classes = 'col-span-full'
        break
      default:
        classes = 'col-span-2 row-span-1'
    }
    
    return classes
  }

  onWidgetRemoved(event) {
    this.updateWidgetCount()
    this.checkEmptyState()
    this.saveDashboardState()
  }

  onWidgetToggled(event) {
    this.saveDashboardState()
  }

  updateWidgetCount() {
    if (this.hasWidgetCountTarget) {
      const count = this.gridTarget.children.length
      this.widgetCountTarget.textContent = `${count} widget${count !== 1 ? 's' : ''}`
    }
  }

  checkEmptyState() {
    const hasWidgets = this.gridTarget.children.length > 0
    
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle('hidden', hasWidgets)
    }
    
    this.gridTarget.classList.toggle('hidden', !hasWidgets)
  }

  toggleEditMode() {
    this.editMode = !this.editMode
    
    // Update UI
    if (this.hasEditModeTextTarget) {
      this.editModeTextTarget.textContent = this.editMode ? 'Exit Edit Mode' : 'Edit Mode'
    }
    
    // Toggle edit classes on widgets
    const widgets = this.gridTarget.querySelectorAll('.dashboard-widget')
    widgets.forEach(widget => {
      widget.classList.toggle('edit-mode', this.editMode)
    })
    
    // Show/hide edit controls
    this.element.classList.toggle('dashboard-edit-mode', this.editMode)
  }

  resetLayout() {
    if (confirm('Are you sure you want to reset the dashboard layout? This will remove all widgets.')) {
      this.gridTarget.innerHTML = ''
      this.widgets = []
      this.updateWidgetCount()
      this.checkEmptyState()
      this.clearDashboardState()
    }
  }

  exportLayout() {
    const layout = {
      columns: this.columnsValue,
      widgets: this.widgets,
      timestamp: new Date().toISOString()
    }
    
    const dataStr = JSON.stringify(layout, null, 2)
    const dataBlob = new Blob([dataStr], { type: 'application/json' })
    
    const link = document.createElement('a')
    link.href = URL.createObjectURL(dataBlob)
    link.download = `dashboard-layout-${new Date().toISOString().split('T')[0]}.json`
    link.click()
  }

  importLayout() {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = '.json'
    input.onchange = (e) => {
      const file = e.target.files[0]
      if (file) {
        const reader = new FileReader()
        reader.onload = (e) => {
          try {
            const layout = JSON.parse(e.target.result)
            this.loadLayout(layout)
          } catch (error) {
            alert('Invalid layout file format')
          }
        }
        reader.readAsText(file)
      }
    }
    input.click()
  }

  loadLayout(layout) {
    // Clear current layout
    this.gridTarget.innerHTML = ''
    
    // Set columns
    this.columnsValue = layout.columns || 4
    this.updateGridColumns(this.columnsValue)
    
    // Add widgets
    this.widgets = layout.widgets || []
    this.widgets.forEach(widgetOptions => {
      this.createWidget(widgetOptions)
    })
    
    this.updateWidgetCount()
    this.checkEmptyState()
  }

  saveDashboardState() {
    const state = {
      columns: this.columnsValue,
      widgets: this.widgets,
      editMode: this.editMode
    }
    
    localStorage.setItem('dashboard-state', JSON.stringify(state))
  }

  loadDashboardState() {
    const savedState = localStorage.getItem('dashboard-state')
    if (!savedState) return
    
    try {
      const state = JSON.parse(savedState)
      
      if (state.columns) {
        this.columnsValue = state.columns
        this.updateGridColumns(state.columns)
      }
      
      if (state.editMode) {
        this.editMode = state.editMode
      }
      
    } catch (error) {
      console.error('Failed to load dashboard state:', error)
    }
  }

  clearDashboardState() {
    localStorage.removeItem('dashboard-state')
  }

  showAddWidgetModal() {
    if (this.hasAddWidgetModalTarget) {
      this.addWidgetModalTarget.showModal()
    }
  }

  selectWidgetType(event) {
    const widgetType = event.currentTarget.dataset.widgetType
    const widgetTitle = this.getDefaultWidgetTitle(widgetType)
    
    this.createWidget({
      type: widgetType,
      title: widgetTitle,
      size: 'medium',
      removable: true,
      draggable: this.sortableValue
    })
    
    if (this.hasAddWidgetModalTarget) {
      this.addWidgetModalTarget.close()
    }
  }

  getDefaultWidgetTitle(type) {
    const titles = {
      'metric': 'Performance Metrics',
      'chart': 'Analytics Chart',
      'list': 'Recent Items',
      'activity': 'Activity Feed'
    }
    
    return titles[type] || 'New Widget'
  }
}