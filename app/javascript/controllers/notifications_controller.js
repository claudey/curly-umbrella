import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "badge", "count"]
  static values = { 
    updateUrl: String,
    markAllReadUrl: String 
  }

  connect() {
    this.updateUnreadCount()
    // Poll for new notifications every 30 seconds
    this.pollInterval = setInterval(() => {
      this.updateUnreadCount()
    }, 30000)
  }

  disconnect() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }

  toggle() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.toggle("hidden")
    }
  }

  close() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.add("hidden")
    }
  }

  markAsRead(event) {
    const notificationId = event.currentTarget.dataset.notificationId
    
    fetch(`/notifications/${notificationId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        action_type: 'mark_as_read'
      })
    }).then(() => {
      this.updateUnreadCount()
      // Remove unread styling
      const notificationElement = event.currentTarget.closest('.notification-item')
      if (notificationElement) {
        notificationElement.classList.remove('unread')
        const badge = notificationElement.querySelector('.badge-primary')
        if (badge) badge.remove()
      }
    })
  }

  markAllAsRead() {
    if (confirm('Mark all notifications as read?')) {
      fetch(this.markAllReadUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      }).then(() => {
        this.updateUnreadCount()
        // Remove all unread styling
        document.querySelectorAll('.notification-item.unread').forEach(item => {
          item.classList.remove('unread')
          const badge = item.querySelector('.badge-primary')
          if (badge) badge.remove()
        })
      })
    }
  }

  updateUnreadCount() {
    if (this.updateUrlValue) {
      fetch(this.updateUrlValue)
        .then(response => response.json())
        .then(data => {
          if (this.hasCountTarget) {
            this.countTarget.textContent = data.count
          }
          
          if (this.hasBadgeTarget) {
            if (data.count > 0) {
              this.badgeTarget.textContent = data.count > 99 ? '99+' : data.count
              this.badgeTarget.classList.remove('hidden')
            } else {
              this.badgeTarget.classList.add('hidden')
            }
          }
        })
        .catch(error => {
          console.error('Error updating notification count:', error)
        })
    }
  }

  // Close dropdown when clicking outside
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}