import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]
  static values = { 
    rules: Object,
    realtime: Boolean,
    showSuccess: Boolean
  }

  connect() {
    this.setupValidation()
    this.isValid = false
    this.errors = {}
  }

  setupValidation() {
    // Add event listeners for real-time validation
    if (this.realtimeValue) {
      this.fieldTargets.forEach(field => {
        field.addEventListener('blur', (e) => this.validateField(e.target))
        field.addEventListener('input', (e) => this.clearFieldError(e.target))
      })
    }

    // Add form submission validation
    const form = this.element.closest('form')
    if (form) {
      form.addEventListener('submit', (e) => this.validateForm(e))
    }
  }

  validateField(field) {
    const fieldName = this.getFieldName(field)
    const rules = this.rulesValue[fieldName] || {}
    const value = this.getFieldValue(field)
    
    this.clearFieldError(field)
    
    const errors = this.runValidationRules(value, rules, fieldName)
    
    if (errors.length > 0) {
      this.showFieldError(field, errors[0])
      this.errors[fieldName] = errors
      return false
    } else {
      if (this.showSuccessValue) {
        this.showFieldSuccess(field)
      }
      delete this.errors[fieldName]
      return true
    }
  }

  validateForm(event) {
    let isFormValid = true
    this.errors = {}

    this.fieldTargets.forEach(field => {
      if (!this.validateField(field)) {
        isFormValid = false
      }
    })

    if (!isFormValid) {
      event.preventDefault()
      this.focusFirstError()
      this.showFormErrors()
    }

    this.isValid = isFormValid
    this.dispatch('validated', { 
      detail: { 
        valid: isFormValid, 
        errors: this.errors 
      } 
    })

    return isFormValid
  }

  runValidationRules(value, rules, fieldName) {
    const errors = []

    // Required validation
    if (rules.required && (!value || value.toString().trim() === '')) {
      errors.push(rules.requiredMessage || `${fieldName.replace(/_/g, ' ')} is required`)
    }

    // Skip other validations if field is empty and not required
    if (!value || value.toString().trim() === '') {
      return errors
    }

    // Length validations
    if (rules.minLength && value.length < rules.minLength) {
      errors.push(rules.minLengthMessage || `Must be at least ${rules.minLength} characters`)
    }

    if (rules.maxLength && value.length > rules.maxLength) {
      errors.push(rules.maxLengthMessage || `Must be no more than ${rules.maxLength} characters`)
    }

    // Numeric validations
    if (rules.min !== undefined) {
      const numValue = parseFloat(value)
      if (isNaN(numValue) || numValue < rules.min) {
        errors.push(rules.minMessage || `Must be at least ${rules.min}`)
      }
    }

    if (rules.max !== undefined) {
      const numValue = parseFloat(value)
      if (isNaN(numValue) || numValue > rules.max) {
        errors.push(rules.maxMessage || `Must be no more than ${rules.max}`)
      }
    }

    // Pattern validation
    if (rules.pattern) {
      const regex = new RegExp(rules.pattern)
      if (!regex.test(value)) {
        errors.push(rules.patternMessage || 'Invalid format')
      }
    }

    // Email validation
    if (rules.email) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      if (!emailRegex.test(value)) {
        errors.push(rules.emailMessage || 'Please enter a valid email address')
      }
    }

    // Phone validation
    if (rules.phone) {
      const phoneRegex = /^[\+]?[1-9][\d]{0,15}$/
      if (!phoneRegex.test(value.replace(/[\s\-\(\)]/g, ''))) {
        errors.push(rules.phoneMessage || 'Please enter a valid phone number')
      }
    }

    // URL validation
    if (rules.url) {
      try {
        new URL(value)
      } catch {
        errors.push(rules.urlMessage || 'Please enter a valid URL')
      }
    }

    // Custom validation function
    if (rules.custom && typeof window[rules.custom] === 'function') {
      const customResult = window[rules.custom](value, fieldName)
      if (customResult !== true) {
        errors.push(customResult || 'Invalid value')
      }
    }

    // Confirmation validation (e.g., password confirmation)
    if (rules.confirmation) {
      const confirmationField = this.element.querySelector(`[name*="${rules.confirmation}"]`)
      if (confirmationField && value !== this.getFieldValue(confirmationField)) {
        errors.push(rules.confirmationMessage || 'Values do not match')
      }
    }

    return errors
  }

  getFieldName(field) {
    return field.name.split('[').pop().replace(']', '') || field.id
  }

  getFieldValue(field) {
    if (field.type === 'checkbox') {
      return field.checked
    } else if (field.type === 'radio') {
      const checkedRadio = this.element.querySelector(`input[name="${field.name}"]:checked`)
      return checkedRadio ? checkedRadio.value : ''
    } else if (field.tagName === 'SELECT' && field.multiple) {
      return Array.from(field.selectedOptions).map(option => option.value)
    } else {
      return field.value
    }
  }

  showFieldError(field, message) {
    this.clearFieldError(field)
    
    // Add error classes
    field.classList.add(this.getErrorClass(field))
    
    // Create error message element
    const errorElement = document.createElement('span')
    errorElement.className = 'label-text-alt text-error field-error'
    errorElement.textContent = message
    
    // Find the label container and append error
    const formControl = field.closest('.form-control')
    if (formControl) {
      let labelContainer = formControl.querySelector('.label:last-child')
      if (!labelContainer) {
        labelContainer = document.createElement('div')
        labelContainer.className = 'label'
        formControl.appendChild(labelContainer)
      }
      labelContainer.appendChild(errorElement)
    }

    // Add shake animation
    field.classList.add('animate-shake')
    setTimeout(() => field.classList.remove('animate-shake'), 500)
  }

  showFieldSuccess(field) {
    this.clearFieldError(field)
    field.classList.add(this.getSuccessClass(field))
    
    // Add success icon
    const formControl = field.closest('.form-control')
    if (formControl && !formControl.querySelector('.success-icon')) {
      const icon = document.createElement('span')
      icon.className = 'success-icon absolute right-3 top-1/2 transform -translate-y-1/2 text-success'
      icon.innerHTML = '✓'
      
      const fieldContainer = field.parentElement
      if (fieldContainer) {
        fieldContainer.style.position = 'relative'
        fieldContainer.appendChild(icon)
      }
    }
  }

  clearFieldError(field) {
    // Remove error classes
    field.classList.remove(this.getErrorClass(field), this.getSuccessClass(field))
    
    // Remove error messages
    const formControl = field.closest('.form-control')
    if (formControl) {
      const errorElements = formControl.querySelectorAll('.field-error')
      errorElements.forEach(el => el.remove())
      
      const successIcons = formControl.querySelectorAll('.success-icon')
      successIcons.forEach(el => el.remove())
    }
  }

  getErrorClass(field) {
    if (field.classList.contains('input')) return 'input-error'
    if (field.classList.contains('select')) return 'select-error'
    if (field.classList.contains('textarea')) return 'textarea-error'
    if (field.classList.contains('file-input')) return 'file-input-error'
    return 'border-error'
  }

  getSuccessClass(field) {
    if (field.classList.contains('input')) return 'input-success'
    if (field.classList.contains('select')) return 'select-success'
    if (field.classList.contains('textarea')) return 'textarea-success'
    if (field.classList.contains('file-input')) return 'file-input-success'
    return 'border-success'
  }

  focusFirstError() {
    const firstErrorField = this.fieldTargets.find(field => {
      const fieldName = this.getFieldName(field)
      return this.errors[fieldName]
    })
    
    if (firstErrorField) {
      firstErrorField.focus()
      firstErrorField.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  }

  showFormErrors() {
    const errorCount = Object.keys(this.errors).length
    if (errorCount > 0) {
      this.showToast(`Please fix ${errorCount} error${errorCount > 1 ? 's' : ''} before submitting`, 'error')
    }
  }

  showToast(message, type = 'info') {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = `alert alert-${type} shadow-lg mb-4 animate-slide-in-right max-w-sm`
    toast.innerHTML = `
      <div class="flex-1">
        <span>${message}</span>
      </div>
      <button class="btn btn-sm btn-ghost" onclick="this.parentElement.remove()">×</button>
    `
    
    // Add to toast container
    let container = document.getElementById('toast-container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'toast-container'
      container.className = 'fixed top-4 right-4 z-50 space-y-2'
      document.body.appendChild(container)
    }
    
    container.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove()
      }
    }, 5000)
  }

  // Public methods
  validate() {
    return this.validateForm({ preventDefault: () => {} })
  }

  reset() {
    this.fieldTargets.forEach(field => this.clearFieldError(field))
    this.errors = {}
    this.isValid = false
  }

  getErrors() {
    return this.errors
  }

  isFormValid() {
    return this.isValid
  }
}

// Add CSS for animations
document.addEventListener('DOMContentLoaded', () => {
  if (!document.getElementById('form-validation-styles')) {
    const style = document.createElement('style')
    style.id = 'form-validation-styles'
    style.textContent = `
      @keyframes shake {
        0%, 100% { transform: translateX(0); }
        25% { transform: translateX(-5px); }
        75% { transform: translateX(5px); }
      }
      
      .animate-shake {
        animation: shake 0.5s ease-in-out;
      }
      
      .input-success, .select-success, .textarea-success, .file-input-success {
        border-color: oklch(var(--su)) !important;
      }
      
      .field-error {
        animation: fadeIn 0.3s ease-out;
      }
      
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-10px); }
        to { opacity: 1; transform: translateY(0); }
      }
    `
    document.head.appendChild(style)
  }
})