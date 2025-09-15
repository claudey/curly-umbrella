import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "applicationSelect",
    "companySelect", 
    "premiumAmount",
    "commissionRate",
    "premiumDisplay",
    "commissionRateDisplay", 
    "commissionAmountDisplay",
    "totalDisplay",
    "coverageContainer"
  ]

  connect() {
    this.updateDisplays()
  }

  calculateCommission() {
    this.updateDisplays()
  }

  updateDisplays() {
    const premium = parseFloat(this.premiumAmountTarget.value) || 0
    const commissionRate = parseFloat(this.commissionRateTarget.value) || 0
    const commissionAmount = premium * (commissionRate / 100)
    const total = premium + commissionAmount

    // Update displays
    this.premiumDisplayTarget.textContent = this.formatCurrency(premium)
    this.commissionRateDisplayTarget.textContent = `${commissionRate.toFixed(1)}%`
    this.commissionAmountDisplayTarget.textContent = this.formatCurrency(commissionAmount)
    this.totalDisplayTarget.textContent = this.formatCurrency(total)

    // Update form styling based on values
    this.updateFormState(premium, commissionRate)
  }

  updateFormState(premium, commissionRate) {
    const isValid = premium > 0 && commissionRate >= 0

    // Add visual feedback for valid/invalid state
    const premiumInput = this.premiumAmountTarget
    const commissionInput = this.commissionRateTarget

    if (premium > 0) {
      premiumInput.classList.remove('input-error')
      premiumInput.classList.add('input-success')
    } else {
      premiumInput.classList.remove('input-success')
      if (premium === 0 && premiumInput.value !== '') {
        premiumInput.classList.add('input-error')
      }
    }

    if (commissionRate >= 0 && commissionRate <= 100) {
      commissionInput.classList.remove('input-error')
      if (commissionRate > 0) {
        commissionInput.classList.add('input-success')
      }
    } else {
      commissionInput.classList.remove('input-success')
      commissionInput.classList.add('input-error')
    }
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2
    }).format(amount)
  }

  // Handle application selection change
  applicationChanged() {
    const selectedOption = this.applicationSelectTarget.selectedOptions[0]
    if (selectedOption && selectedOption.value) {
      // Could fetch application details and pre-populate coverage info
      this.loadApplicationDetails(selectedOption.value)
    }
  }

  // Handle insurance company selection change  
  companyChanged() {
    const selectedOption = this.companySelectTarget.selectedOptions[0]
    if (selectedOption && selectedOption.value) {
      // Could fetch company's default commission rate
      this.loadCompanyDefaults(selectedOption.value)
    }
  }

  async loadApplicationDetails(applicationId) {
    try {
      // This would typically fetch application details from the server
      console.log(`Loading application details for ${applicationId}`)
      // Example: populate coverage details based on application
    } catch (error) {
      console.error('Error loading application details:', error)
    }
  }

  async loadCompanyDefaults(companyId) {
    try {
      // This would typically fetch company defaults from the server
      console.log(`Loading company defaults for ${companyId}`)
      // Example: set default commission rate for this company
    } catch (error) {
      console.error('Error loading company defaults:', error)
    }
  }

  // Validate form before submission
  validateForm(event) {
    const premium = parseFloat(this.premiumAmountTarget.value) || 0
    const commissionRate = parseFloat(this.commissionRateTarget.value) || 0
    const applicationSelected = this.applicationSelectTarget.value
    const companySelected = this.companySelectTarget.value

    const errors = []

    if (!applicationSelected) {
      errors.push('Please select a motor application')
    }

    if (!companySelected) {
      errors.push('Please select an insurance company')
    }

    if (premium <= 0) {
      errors.push('Premium amount must be greater than 0')
    }

    if (commissionRate < 0 || commissionRate > 100) {
      errors.push('Commission rate must be between 0 and 100')
    }

    if (errors.length > 0) {
      event.preventDefault()
      this.showErrors(errors)
      return false
    }

    return true
  }

  showErrors(errors) {
    // Remove existing error alerts
    const existingAlerts = this.element.querySelectorAll('.alert-error.validation-errors')
    existingAlerts.forEach(alert => alert.remove())

    // Create new error alert
    const errorAlert = document.createElement('div')
    errorAlert.className = 'alert alert-error validation-errors mb-4'
    errorAlert.innerHTML = `
      <div>
        <h3 class="font-semibold">Please fix the following errors:</h3>
        <ul class="list-disc list-inside mt-2">
          ${errors.map(error => `<li>${error}</li>`).join('')}
        </ul>
      </div>
    `

    // Insert at the top of the form
    const form = this.element.querySelector('form')
    form.insertBefore(errorAlert, form.firstChild)

    // Scroll to the error alert
    errorAlert.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  // Handle form submission
  submitForm(event) {
    if (!this.validateForm(event)) {
      return false
    }

    // Add loading state
    const submitButtons = this.element.querySelectorAll('input[type="submit"]')
    submitButtons.forEach(button => {
      button.disabled = true
      button.classList.add('loading')
    })

    return true
  }
}