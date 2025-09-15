import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "fileInput", "preview", "uploadButton"]
  static values = { 
    acceptedTypes: String,
    maxFiles: Number,
    maxSize: Number // in MB
  }

  connect() {
    this.setupDropzone()
    this.uploadedFiles = new Set()
    this.maxSizeBytes = (this.maxSizeValue || 10) * 1024 * 1024 // Convert MB to bytes
  }

  setupDropzone() {
    this.dropzoneTarget.addEventListener('dragover', this.handleDragOver.bind(this))
    this.dropzoneTarget.addEventListener('dragleave', this.handleDragLeave.bind(this))
    this.dropzoneTarget.addEventListener('drop', this.handleDrop.bind(this))
    
    // Handle file input change
    if (this.hasFileInputTarget) {
      this.fileInputTarget.addEventListener('change', this.handleFileSelect.bind(this))
    }
  }

  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.add('drag-over')
    this.showDropIndicator()
  }

  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    
    // Only remove drag-over if we're actually leaving the dropzone
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove('drag-over')
      this.hideDropIndicator()
    }
  }

  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.remove('drag-over')
    this.hideDropIndicator()

    const files = Array.from(event.dataTransfer.files)
    this.processFiles(files)
  }

  handleFileSelect(event) {
    const files = Array.from(event.target.files)
    this.processFiles(files)
  }

  processFiles(files) {
    const validFiles = this.validateFiles(files)
    
    if (validFiles.length > 0) {
      this.displayPreviews(validFiles)
      this.enableUploadButton()
    }
  }

  validateFiles(files) {
    const validFiles = []
    const acceptedTypes = this.acceptedTypesValue ? this.acceptedTypesValue.split(',').map(t => t.trim()) : []
    const maxFiles = this.maxFilesValue || 10

    // Check if adding these files would exceed the limit
    if (this.uploadedFiles.size + files.length > maxFiles) {
      this.showError(`Maximum ${maxFiles} files allowed. You can upload ${maxFiles - this.uploadedFiles.size} more.`)
      return []
    }

    files.forEach(file => {
      // Check file size
      if (file.size > this.maxSizeBytes) {
        this.showError(`File "${file.name}" is too large. Maximum size is ${this.maxSizeValue}MB.`)
        return
      }

      // Check file type if specified
      if (acceptedTypes.length > 0) {
        const fileType = file.type
        const fileExtension = '.' + file.name.split('.').pop().toLowerCase()
        
        if (!acceptedTypes.some(type => 
          type === fileType || type === fileExtension || 
          (type.includes('*') && fileType.startsWith(type.replace('*', '')))
        )) {
          this.showError(`File "${file.name}" is not an accepted file type. Accepted types: ${acceptedTypes.join(', ')}`)
          return
        }
      }

      // Check for duplicates
      if (!this.uploadedFiles.has(file.name)) {
        validFiles.push(file)
        this.uploadedFiles.add(file.name)
      }
    })

    return validFiles
  }

  displayPreviews(files) {
    if (!this.hasPreviewTarget) return

    files.forEach(file => {
      const previewElement = this.createPreviewElement(file)
      this.previewTarget.appendChild(previewElement)
    })

    this.updateDropzoneState()
  }

  createPreviewElement(file) {
    const div = document.createElement('div')
    div.className = 'file-preview-item card card-compact bg-base-100 shadow border'
    div.dataset.fileName = file.name
    
    const isImage = file.type.startsWith('image/')
    
    div.innerHTML = `
      <div class="card-body">
        <div class="flex items-center gap-3">
          <div class="file-icon">
            ${isImage ? 
              `<div class="w-12 h-12 bg-base-200 rounded flex items-center justify-center">
                 <i class="ph ph-image text-primary text-xl"></i>
               </div>` :
              `<div class="w-12 h-12 bg-base-200 rounded flex items-center justify-center">
                 <i class="ph ph-file text-primary text-xl"></i>
               </div>`
            }
          </div>
          <div class="flex-1 min-w-0">
            <div class="font-medium text-sm truncate" title="${file.name}">${file.name}</div>
            <div class="text-xs text-base-content/60">${this.formatFileSize(file.size)}</div>
            <div class="progress-container mt-1" style="display: none;">
              <progress class="progress progress-primary w-full" value="0" max="100"></progress>
            </div>
          </div>
          <div class="flex-shrink-0">
            <button type="button" class="btn btn-ghost btn-xs" data-action="click->drag-drop#removeFile">
              <i class="ph ph-x"></i>
            </button>
          </div>
        </div>
      </div>
    `

    // If it's an image, create a thumbnail
    if (isImage) {
      const reader = new FileReader()
      reader.onload = (e) => {
        const img = div.querySelector('.file-icon div')
        img.innerHTML = `<img src="${e.target.result}" alt="${file.name}" class="w-12 h-12 object-cover rounded">`
      }
      reader.readAsDataURL(file)
    }

    return div
  }

  removeFile(event) {
    const fileItem = event.target.closest('.file-preview-item')
    const fileName = fileItem.dataset.fileName
    
    this.uploadedFiles.delete(fileName)
    fileItem.remove()
    
    this.updateDropzoneState()
    
    if (this.uploadedFiles.size === 0) {
      this.disableUploadButton()
    }
  }

  updateDropzoneState() {
    if (this.uploadedFiles.size > 0) {
      this.dropzoneTarget.classList.add('has-files')
    } else {
      this.dropzoneTarget.classList.remove('has-files')
    }
  }

  showDropIndicator() {
    const indicator = this.dropzoneTarget.querySelector('.drop-indicator')
    if (indicator) {
      indicator.style.display = 'flex'
    }
  }

  hideDropIndicator() {
    const indicator = this.dropzoneTarget.querySelector('.drop-indicator')
    if (indicator) {
      indicator.style.display = 'none'
    }
  }

  enableUploadButton() {
    if (this.hasUploadButtonTarget) {
      this.uploadButtonTarget.disabled = false
      this.uploadButtonTarget.classList.remove('btn-disabled')
    }
  }

  disableUploadButton() {
    if (this.hasUploadButtonTarget) {
      this.uploadButtonTarget.disabled = true
      this.uploadButtonTarget.classList.add('btn-disabled')
    }
  }

  triggerFileSelect() {
    if (this.hasFileInputTarget) {
      this.fileInputTarget.click()
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  showError(message) {
    // Create and show error toast
    const toast = document.createElement('div')
    toast.className = 'toast toast-top toast-end'
    toast.innerHTML = `
      <div class="alert alert-error">
        <i class="ph ph-warning-circle"></i>
        <span>${message}</span>
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      toast.remove()
    }, 5000)
  }

  // Method to handle actual upload (can be overridden or extended)
  uploadFiles() {
    const fileItems = this.previewTarget.querySelectorAll('.file-preview-item')
    
    fileItems.forEach(item => {
      const progressContainer = item.querySelector('.progress-container')
      const progress = item.querySelector('progress')
      
      progressContainer.style.display = 'block'
      
      // Simulate upload progress (replace with actual upload logic)
      let currentProgress = 0
      const progressInterval = setInterval(() => {
        currentProgress += Math.random() * 30
        if (currentProgress >= 100) {
          currentProgress = 100
          clearInterval(progressInterval)
          this.markFileAsUploaded(item)
        }
        progress.value = currentProgress
      }, 200)
    })
  }

  markFileAsUploaded(fileItem) {
    fileItem.classList.add('uploaded')
    const removeButton = fileItem.querySelector('button')
    removeButton.innerHTML = '<i class="ph ph-check text-success"></i>'
    removeButton.disabled = true
  }
}