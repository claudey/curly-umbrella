import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "nextButton", "prevButton", "progress", "progressBar"]
  static values = { 
    currentStep: Number,
    totalSteps: Number 
  }

  connect() {
    this.currentStepValue = 1
    this.totalStepsValue = this.stepTargets.length
    this.updateDisplay()
  }

  next() {
    if (this.canGoNext()) {
      this.currentStepValue++
      this.updateDisplay()
      this.scrollToTop()
    }
  }

  previous() {
    if (this.canGoPrevious()) {
      this.currentStepValue--
      this.updateDisplay()
      this.scrollToTop()
    }
  }

  goToStep(event) {
    const stepNumber = parseInt(event.currentTarget.dataset.step)
    if (stepNumber >= 1 && stepNumber <= this.totalStepsValue) {
      this.currentStepValue = stepNumber
      this.updateDisplay()
      this.scrollToTop()
    }
  }

  updateDisplay() {
    // Hide all steps
    this.stepTargets.forEach((step, index) => {
      if (index + 1 === this.currentStepValue) {
        step.classList.remove("hidden")
        step.classList.add("block")
      } else {
        step.classList.add("hidden")
        step.classList.remove("block")
      }
    })

    // Update navigation buttons
    this.updateNavigationButtons()
    
    // Update progress bar
    this.updateProgressBar()
    
    // Dispatch custom event
    this.dispatch("stepChanged", { 
      detail: { 
        currentStep: this.currentStepValue, 
        totalSteps: this.totalStepsValue 
      } 
    })
  }

  updateNavigationButtons() {
    // Update previous button
    if (this.hasPrevButtonTarget) {
      if (this.canGoPrevious()) {
        this.prevButtonTarget.removeAttribute("disabled")
        this.prevButtonTarget.classList.remove("btn-disabled")
      } else {
        this.prevButtonTarget.setAttribute("disabled", "true")
        this.prevButtonTarget.classList.add("btn-disabled")
      }
    }

    // Update next button
    if (this.hasNextButtonTarget) {
      if (this.canGoNext()) {
        this.nextButtonTarget.removeAttribute("disabled")
        this.nextButtonTarget.classList.remove("btn-disabled")
        this.nextButtonTarget.textContent = this.isLastStep() ? "Submit" : "Next"
      } else {
        this.nextButtonTarget.setAttribute("disabled", "true")
        this.nextButtonTarget.classList.add("btn-disabled")
      }
    }
  }

  updateProgressBar() {
    const progressPercentage = (this.currentStepValue / this.totalStepsValue) * 100
    
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${progressPercentage}%`
      this.progressBarTarget.setAttribute("aria-valuenow", progressPercentage)
    }

    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `Step ${this.currentStepValue} of ${this.totalStepsValue}`
    }
  }

  canGoNext() {
    return this.currentStepValue < this.totalStepsValue
  }

  canGoPrevious() {
    return this.currentStepValue > 1
  }

  isFirstStep() {
    return this.currentStepValue === 1
  }

  isLastStep() {
    return this.currentStepValue === this.totalStepsValue
  }

  scrollToTop() {
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  // Method to validate current step before allowing navigation
  validateCurrentStep() {
    const currentStepElement = this.stepTargets[this.currentStepValue - 1]
    const requiredInputs = currentStepElement.querySelectorAll("input[required], select[required], textarea[required]")
    
    let isValid = true
    requiredInputs.forEach(input => {
      if (!input.value.trim()) {
        isValid = false
        input.classList.add("input-error")
      } else {
        input.classList.remove("input-error")
      }
    })

    return isValid
  }

  // Enhanced next method with validation
  nextWithValidation() {
    if (this.validateCurrentStep() && this.canGoNext()) {
      this.next()
    } else if (!this.validateCurrentStep()) {
      // Show validation errors
      this.dispatch("validationError", { 
        detail: { step: this.currentStepValue } 
      })
    }
  }
}