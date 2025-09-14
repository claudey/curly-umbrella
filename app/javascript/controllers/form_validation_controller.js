import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "error"]
  static values = { 
    realtime: Boolean,
    submitButton: String 
  }

  connect() {
    this.setupValidation()
    this.updateSubmitButton()
  }

  setupValidation() {
    this.fieldTargets.forEach(field => {
      // Add real-time validation listeners
      if (this.realtimeValue) {
        field.addEventListener('blur', () => this.validateField(field))
        field.addEventListener('input', () => this.clearFieldError(field))
      }

      // Add form submission validation
      field.addEventListener('invalid', (event) => {
        event.preventDefault()
        this.showFieldError(field, field.validationMessage)
      })
    })

    // Intercept form submission for custom validation
    this.element.addEventListener('submit', (event) => {
      if (!this.validateForm()) {
        event.preventDefault()
        this.focusFirstInvalidField()
      }
    })
  }

  validateField(field) {
    this.clearFieldError(field)

    // Check HTML5 validity first
    if (!field.checkValidity()) {
      this.showFieldError(field, field.validationMessage)
      return false
    }

    // Custom validation rules
    const isValid = this.runCustomValidation(field)
    
    if (isValid) {
      this.showFieldSuccess(field)
    }

    this.updateSubmitButton()
    return isValid
  }

  validateForm() {
    let isValid = true
    
    this.fieldTargets.forEach(field => {
      if (!this.validateField(field)) {
        isValid = false
      }
    })

    return isValid
  }

  runCustomValidation(field) {
    const fieldName = field.name
    const value = field.value.trim()

    // Custom validation rules based on field type/name
    switch (field.type) {
      case 'email':
        return this.validateEmail(field, value)
      case 'tel':
        return this.validatePhone(field, value)
      case 'date':
        return this.validateDate(field, value)
      case 'number':
        return this.validateNumber(field, value)
      default:
        // Field-specific validations
        if (fieldName.includes('license_expiry')) {
          return this.validateLicenseExpiry(field, value)
        }
        if (fieldName.includes('coverage_end_date')) {
          return this.validateCoverageEndDate(field, value)
        }
        return true
    }
  }

  validateEmail(field, value) {
    if (!value) return true // Allow empty if not required
    
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(value)) {
      this.showFieldError(field, 'Please enter a valid email address')
      return false
    }
    return true
  }

  validatePhone(field, value) {
    if (!value) return true // Allow empty if not required
    
    const phoneRegex = /^[\+]?[\d\s\-\(\)]{10,}$/
    if (!phoneRegex.test(value)) {
      this.showFieldError(field, 'Please enter a valid phone number')
      return false
    }
    return true
  }

  validateDate(field, value) {
    if (!value) return true // Allow empty if not required
    
    const date = new Date(value)
    if (isNaN(date.getTime())) {
      this.showFieldError(field, 'Please enter a valid date')
      return false
    }
    return true
  }

  validateNumber(field, value) {
    if (!value) return true // Allow empty if not required
    
    const num = parseFloat(value)
    if (isNaN(num)) {
      this.showFieldError(field, 'Please enter a valid number')
      return false
    }

    // Check min/max attributes
    const min = field.getAttribute('min')
    const max = field.getAttribute('max')
    
    if (min && num < parseFloat(min)) {
      this.showFieldError(field, `Value must be at least ${min}`)
      return false
    }
    
    if (max && num > parseFloat(max)) {
      this.showFieldError(field, `Value must be no more than ${max}`)
      return false
    }
    
    return true
  }

  validateLicenseExpiry(field, value) {
    if (!value) return true
    
    const expiryDate = new Date(value)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    
    if (expiryDate <= today) {
      this.showFieldError(field, 'License expiry date must be in the future')
      return false
    }
    
    return true
  }

  validateCoverageEndDate(field, value) {
    if (!value) return true
    
    const startDateField = this.element.querySelector('[name*="coverage_start_date"]')
    if (!startDateField || !startDateField.value) return true
    
    const startDate = new Date(startDateField.value)
    const endDate = new Date(value)
    
    if (endDate <= startDate) {
      this.showFieldError(field, 'Coverage end date must be after start date')
      return false
    }
    
    return true
  }

  showFieldError(field, message) {
    this.clearFieldError(field)
    
    // Add error styling to field
    field.classList.add('input-error', 'select-error', 'textarea-error')
    field.classList.remove('input-success', 'select-success', 'textarea-success')
    
    // Create and show error message
    const errorElement = document.createElement('div')
    errorElement.className = 'label'
    errorElement.innerHTML = `<span class="label-text-alt text-error">${message}</span>`
    errorElement.dataset.validationError = 'true'
    
    // Insert error after the field or its wrapper
    const wrapper = field.closest('.form-control') || field.parentElement
    wrapper.appendChild(errorElement)
    
    // Dispatch custom event
    this.dispatch('fieldError', { 
      detail: { field: field.name, message } 
    })
  }

  showFieldSuccess(field) {
    this.clearFieldError(field)
    
    // Add success styling
    field.classList.add('input-success', 'select-success', 'textarea-success')
    field.classList.remove('input-error', 'select-error', 'textarea-error')
  }

  clearFieldError(field) {
    // Remove error styling
    field.classList.remove('input-error', 'select-error', 'textarea-error', 'input-success', 'select-success', 'textarea-success')
    
    // Remove error messages
    const wrapper = field.closest('.form-control') || field.parentElement
    const errorElements = wrapper.querySelectorAll('[data-validation-error="true"]')
    errorElements.forEach(element => element.remove())
  }

  updateSubmitButton() {
    if (!this.submitButtonValue) return
    
    const submitButton = this.element.querySelector(this.submitButtonValue)
    if (!submitButton) return
    
    const isFormValid = this.fieldTargets.every(field => {
      return !field.required || (field.value.trim() && field.checkValidity())
    })
    
    submitButton.disabled = !isFormValid
    submitButton.classList.toggle('btn-disabled', !isFormValid)
  }

  focusFirstInvalidField() {
    const firstInvalidField = this.fieldTargets.find(field => !field.checkValidity())
    if (firstInvalidField) {
      firstInvalidField.focus()
      firstInvalidField.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  }

  // Public method to trigger validation
  validate() {
    return this.validateForm()
  }

  // Public method to clear all errors
  clearErrors() {
    this.fieldTargets.forEach(field => this.clearFieldError(field))
  }
}