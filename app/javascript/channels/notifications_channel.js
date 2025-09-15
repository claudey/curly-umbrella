import consumer from "channels/consumer"

const notificationsChannel = consumer.subscriptions.create("NotificationsChannel", {
  connected() {
    console.log("Connected to notifications channel")
    this.updateConnectionStatus(true)
  },

  disconnected() {
    console.log("Disconnected from notifications channel")
    this.updateConnectionStatus(false)
  },

  received(data) {
    console.log("Received notification:", data)
    
    switch(data.type) {
      case 'new_notification':
        this.handleNewNotification(data)
        break
      case 'notification_marked_read':
        this.handleNotificationRead(data)
        break
      case 'all_notifications_marked_read':
        this.handleAllNotificationsRead(data)
        break
      case 'application_distributed':
        this.handleApplicationDistributed(data)
        break
      case 'quote_status_update':
        this.handleQuoteStatusUpdate(data)
        break
      default:
        console.log("Unknown notification type:", data.type)
    }
  },

  handleNewNotification(data) {
    // Update notification badge count
    this.updateNotificationCount(data.unread_count)
    
    // Show toast notification
    this.showToastNotification(data.notification)
    
    // Add to notification dropdown if it's open
    this.addToNotificationDropdown(data.notification)
    
    // Play notification sound if enabled
    this.playNotificationSound()
  },

  handleNotificationRead(data) {
    this.updateNotificationCount(data.unread_count)
    this.markNotificationAsRead(data.notification_id)
  },

  handleAllNotificationsRead(data) {
    this.updateNotificationCount(0)
    this.markAllNotificationsAsRead()
  },

  handleApplicationDistributed(data) {
    // Refresh applications page if user is on it
    if (window.location.pathname.includes('/applications')) {
      this.refreshCurrentPage()
    }
    
    // Show specific toast for new applications
    this.showToastNotification({
      title: "New Application Available",
      message: `A new ${data.coverage_type} application is ready for quoting`,
      type: "info"
    })
  },

  handleQuoteStatusUpdate(data) {
    // Refresh quotes page if user is on it
    if (window.location.pathname.includes('/quotes')) {
      this.refreshCurrentPage()
    }
    
    // Show status-specific toast
    const statusMessages = {
      'approved': 'Your quote has been approved!',
      'rejected': 'Your quote was not selected',
      'accepted': 'Congratulations! Your quote was accepted!'
    }
    
    this.showToastNotification({
      title: "Quote Update",
      message: statusMessages[data.status] || `Quote status updated to ${data.status}`,
      type: data.status === 'accepted' ? 'success' : data.status === 'rejected' ? 'warning' : 'info'
    })
  },

  updateNotificationCount(count) {
    const badges = document.querySelectorAll('[data-notification-count]')
    badges.forEach(badge => {
      badge.textContent = count
      badge.style.display = count > 0 ? 'inline' : 'none'
    })
  },

  showToastNotification(notification) {
    // Create toast element
    const toast = document.createElement('div')
    toast.className = `alert alert-${this.getAlertType(notification.type)} shadow-lg mb-4 animate-slide-in-right`
    toast.innerHTML = `
      <div class="flex-1">
        <div class="flex items-center gap-2">
          ${this.getNotificationIcon(notification.type)}
          <div>
            <div class="font-semibold">${notification.title}</div>
            <div class="text-sm opacity-80">${notification.message}</div>
          </div>
        </div>
      </div>
      <button class="btn btn-sm btn-ghost" onclick="this.parentElement.remove()">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      </button>
    `
    
    // Add to toast container
    let container = document.getElementById('toast-container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'toast-container'
      container.className = 'fixed top-4 right-4 z-50 space-y-2 max-w-sm'
      document.body.appendChild(container)
    }
    
    container.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentElement) {
        toast.classList.add('animate-slide-out-right')
        setTimeout(() => toast.remove(), 300)
      }
    }, 5000)
  },

  addToNotificationDropdown(notification) {
    const dropdown = document.querySelector('[data-notification-dropdown]')
    if (!dropdown) return
    
    const notificationElement = document.createElement('div')
    notificationElement.className = 'p-3 hover:bg-base-200 border-b border-base-300'
    notificationElement.innerHTML = `
      <div class="flex items-start gap-3">
        <div class="w-2 h-2 bg-primary rounded-full mt-2 flex-shrink-0"></div>
        <div class="flex-1 min-w-0">
          <div class="font-medium text-sm">${notification.title}</div>
          <div class="text-xs text-base-content/70 mt-1">${notification.message}</div>
          <div class="text-xs text-base-content/50 mt-1">Just now</div>
        </div>
      </div>
    `
    
    dropdown.insertBefore(notificationElement, dropdown.firstChild)
  },

  markNotificationAsRead(notificationId) {
    const notificationElement = document.querySelector(`[data-notification-id="${notificationId}"]`)
    if (notificationElement) {
      notificationElement.classList.remove('unread')
      const indicator = notificationElement.querySelector('.unread-indicator')
      if (indicator) indicator.remove()
    }
  },

  markAllNotificationsAsRead() {
    const notifications = document.querySelectorAll('[data-notification-id]')
    notifications.forEach(notification => {
      notification.classList.remove('unread')
      const indicator = notification.querySelector('.unread-indicator')
      if (indicator) indicator.remove()
    })
  },

  refreshCurrentPage() {
    // Use Turbo to refresh the page if available, otherwise regular reload
    if (window.Turbo) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  },

  playNotificationSound() {
    // Only play if user has enabled sounds and browser supports it
    const audio = new Audio('/notification.mp3')
    audio.volume = 0.3
    audio.play().catch(() => {
      // Ignore errors - user might not have interacted with page yet
    })
  },

  getAlertType(notificationType) {
    switch(notificationType) {
      case 'success': return 'success'
      case 'error': return 'error'
      case 'warning': return 'warning'
      case 'info': 
      default: return 'info'
    }
  },

  getNotificationIcon(type) {
    const icons = {
      'success': '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>',
      'error': '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>',
      'warning': '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path></svg>',
      'info': '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'
    }
    return icons[type] || icons['info']
  },

  updateConnectionStatus(connected) {
    const indicators = document.querySelectorAll('[data-connection-status]')
    indicators.forEach(indicator => {
      indicator.classList.toggle('connected', connected)
      indicator.classList.toggle('disconnected', !connected)
    })
  },

  // Public methods that can be called from other parts of the app
  markAsRead(notificationId) {
    this.perform('mark_as_read', { notification_id: notificationId })
  },

  markAllAsRead() {
    this.perform('mark_all_as_read')
  }
})

// Make channel globally available for other scripts
window.notificationsChannel = notificationsChannel

// Add CSS for animations
const style = document.createElement('style')
style.textContent = `
  @keyframes slide-in-right {
    from { transform: translateX(100%); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
  }
  
  @keyframes slide-out-right {
    from { transform: translateX(0); opacity: 1; }
    to { transform: translateX(100%); opacity: 0; }
  }
  
  .animate-slide-in-right {
    animation: slide-in-right 0.3s ease-out;
  }
  
  .animate-slide-out-right {
    animation: slide-out-right 0.3s ease-in;
  }
`
document.head.appendChild(style)
