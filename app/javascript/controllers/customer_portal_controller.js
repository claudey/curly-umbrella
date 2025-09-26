import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    mobile: { type: Boolean, default: true },
    autoCollapse: { type: Boolean, default: true }
  }

  static targets = ["drawer", "sidebar", "overlay"]

  connect() {
    this.setupResponsiveHandling()
    this.setupNotifications()
    this.setupQuickActions()
    
    // Auto-collapse sidebar on mobile after navigation
    if (this.mobileValue && this.autoCollapseValue) {
      this.setupAutoCollapse()
    }
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener('change', this.handleMediaChange.bind(this))
    }
  }

  setupResponsiveHandling() {
    // Handle responsive behavior
    this.mediaQuery = window.matchMedia('(max-width: 1024px)')
    this.mediaQuery.addEventListener('change', this.handleMediaChange.bind(this))
    this.handleMediaChange(this.mediaQuery)
  }

  setupNotifications() {
    // Setup any notification handling specific to customer portal
    this.loadNotifications()
    
    // Auto-refresh notifications every 5 minutes
    this.notificationInterval = setInterval(() => {
      this.loadNotifications()
    }, 5 * 60 * 1000)
  }

  setupQuickActions() {
    // Setup keyboard shortcuts for common actions
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  setupAutoCollapse() {
    // Auto-collapse sidebar when clicking on navigation links on mobile
    const navLinks = this.element.querySelectorAll('aside .menu a')
    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        if (window.innerWidth < 1024) {
          this.closeSidebar()
        }
      })
    })
  }

  handleMediaChange(mq) {
    // Handle responsive layout changes
    if (mq.matches) {
      // Mobile view
      this.element.classList.add('drawer-mobile')
    } else {
      // Desktop view
      this.element.classList.remove('drawer-mobile')
    }
  }

  handleKeydown(event) {
    // Handle keyboard shortcuts
    if (event.ctrlKey || event.metaKey) {
      switch (event.key) {
        case 'b':
          event.preventDefault()
          this.toggleSidebar()
          break
        case 'h':
          event.preventDefault()
          this.goToHome()
          break
        case 'p':
          event.preventDefault()
          this.goToPolicies()
          break
        case '/':
          event.preventDefault()
          this.focusSearch()
          break
      }
    }

    // Escape key handling
    if (event.key === 'Escape') {
      this.closeSidebar()
      this.closeAllModals()
    }
  }

  toggleSidebar() {
    const drawerToggle = document.getElementById('customer-portal-drawer')
    if (drawerToggle) {
      drawerToggle.checked = !drawerToggle.checked
      
      this.dispatch('sidebarToggled', {
        detail: { open: drawerToggle.checked }
      })
    }
  }

  openSidebar() {
    const drawerToggle = document.getElementById('customer-portal-drawer')
    if (drawerToggle) {
      drawerToggle.checked = true
    }
  }

  closeSidebar() {
    const drawerToggle = document.getElementById('customer-portal-drawer')
    if (drawerToggle) {
      drawerToggle.checked = false
    }
  }

  goToHome() {
    window.location.href = '/customer'
  }

  goToPolicies() {
    window.location.href = '/customer/policies'
  }

  focusSearch() {
    const searchInput = document.querySelector('input[type="search"], input[placeholder*="search" i]')
    if (searchInput) {
      searchInput.focus()
    }
  }

  closeAllModals() {
    const modals = document.querySelectorAll('dialog[open]')
    modals.forEach(modal => modal.close())
  }

  async loadNotifications() {
    try {
      const response = await fetch('/customer/notifications', {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.updateNotificationBadge(data.unreadCount)
        this.updateNotificationList(data.notifications)
      }
    } catch (error) {
      console.error('Failed to load notifications:', error)
    }
  }

  updateNotificationBadge(count) {
    const badge = document.querySelector('[data-notification-badge]')
    if (badge) {
      if (count > 0) {
        badge.textContent = count > 99 ? '99+' : count.toString()
        badge.classList.remove('hidden')
      } else {
        badge.classList.add('hidden')
      }
    }
  }

  updateNotificationList(notifications) {
    const container = document.querySelector('[data-notification-list]')
    if (container && notifications) {
      container.innerHTML = this.renderNotifications(notifications)
    }
  }

  renderNotifications(notifications) {
    if (notifications.length === 0) {
      return `
        <div class="p-4 text-center text-base-content/60">
          <div class="mb-2">📫</div>
          <div>No new notifications</div>
        </div>
      `
    }

    return notifications.map(notification => `
      <div class="p-3 border-b border-base-300 hover:bg-base-200 transition-colors ${notification.read ? '' : 'bg-primary/5 border-l-4 border-l-primary'}">
        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 mt-1">
            ${this.getNotificationIcon(notification.type)}
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium text-base-content">
              ${notification.title}
            </div>
            <div class="text-xs text-base-content/70 mt-1">
              ${notification.message}
            </div>
            <div class="text-xs text-base-content/50 mt-1">
              ${this.formatTimeAgo(notification.createdAt)}
            </div>
          </div>
          ${!notification.read ? '<div class="w-2 h-2 bg-primary rounded-full flex-shrink-0 mt-2"></div>' : ''}
        </div>
      </div>
    `).join('')
  }

  getNotificationIcon(type) {
    const icons = {
      policy: '📄',
      claim: '⚠️',
      payment: '💳',
      renewal: '🔄',
      document: '📎',
      system: 'ℹ️'
    }
    return icons[type] || 'ℹ️'
  }

  formatTimeAgo(timestamp) {
    const now = new Date()
    const time = new Date(timestamp)
    const diffInSeconds = Math.floor((now - time) / 1000)

    if (diffInSeconds < 60) return 'Just now'
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`
    if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d ago`
    
    return time.toLocaleDateString()
  }

  // Policy management actions
  async renewPolicy(event) {
    const policyId = event.currentTarget.dataset.policyId
    if (!policyId) return

    try {
      const response = await fetch(`/customer/policies/${policyId}/renew`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        this.showSuccess('Renewal request submitted successfully')
        window.location.reload()
      } else {
        throw new Error('Failed to submit renewal request')
      }
    } catch (error) {
      this.showError('Failed to submit renewal request')
      console.error('Renewal error:', error)
    }
  }

  async downloadPolicy(event) {
    const policyId = event.currentTarget.dataset.policyId
    if (!policyId) return

    try {
      const response = await fetch(`/customer/policies/${policyId}.pdf`)
      
      if (response.ok) {
        const blob = await response.blob()
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `policy-${policyId}.pdf`
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        window.URL.revokeObjectURL(url)
      } else {
        throw new Error('Failed to download policy')
      }
    } catch (error) {
      this.showError('Failed to download policy document')
      console.error('Download error:', error)
    }
  }

  // Utility methods for user feedback
  showSuccess(message) {
    this.showToast(message, 'success')
  }

  showError(message) {
    this.showToast(message, 'error')
  }

  showToast(message, type = 'info') {
    // Create toast using DaisyUI classes
    const toast = document.createElement('div')
    toast.className = `alert alert-${type} fixed top-4 right-4 z-50 max-w-sm shadow-lg`
    toast.innerHTML = `
      <div class="flex items-center gap-2">
        <span>${message}</span>
        <button class="btn btn-ghost btn-xs" onclick="this.parentElement.parentElement.remove()">×</button>
      </div>
    `

    document.body.appendChild(toast)

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentNode) {
        toast.remove()
      }
    }, 5000)
  }
}