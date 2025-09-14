import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "dropzone", "progress"]
  static values = { 
    maxFiles: Number,
    maxSize: Number,
    acceptedTypes: Array,
    uploadUrl: String
  }

  connect() {
    this.maxFilesValue = this.maxFilesValue || 5
    this.maxSizeValue = this.maxSizeValue || 5 * 1024 * 1024 // 5MB default
    this.acceptedTypesValue = this.acceptedTypesValue || ['image/*', 'application/pdf', '.doc', '.docx']
    this.files = []
    
    this.setupDropzone()
  }

  setupDropzone() {
    if (!this.hasDropzoneTarget) return

    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      this.dropzoneTarget.addEventListener(eventName, this.preventDefaults, false)
      document.body.addEventListener(eventName, this.preventDefaults, false)
    })

    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
      this.dropzoneTarget.addEventListener(eventName, () => this.highlight(), false)
    })

    ['dragleave', 'drop'].forEach(eventName => {
      this.dropzoneTarget.addEventListener(eventName, () => this.unhighlight(), false)
    })

    // Handle dropped files
    this.dropzoneTarget.addEventListener('drop', (e) => this.handleDrop(e), false)
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight() {
    this.dropzoneTarget.classList.add('border-primary', 'bg-primary/5')
  }

  unhighlight() {
    this.dropzoneTarget.classList.remove('border-primary', 'bg-primary/5')
  }

  handleDrop(e) {
    const dt = e.dataTransfer
    const files = dt.files
    this.handleFiles(files)
  }

  inputChanged(event) {
    this.handleFiles(event.target.files)
  }

  handleFiles(fileList) {
    const files = [...fileList]
    
    // Validate file count
    if (this.files.length + files.length > this.maxFilesValue) {
      this.showError(`Maximum ${this.maxFilesValue} files allowed`)
      return
    }

    // Process each file
    files.forEach(file => {
      if (this.validateFile(file)) {
        this.addFile(file)
      }
    })

    this.updatePreview()
  }

  validateFile(file) {
    // Check file size
    if (file.size > this.maxSizeValue) {
      this.showError(`File "${file.name}" is too large. Maximum size is ${this.formatFileSize(this.maxSizeValue)}`)
      return false
    }

    // Check file type
    const isValidType = this.acceptedTypesValue.some(type => {
      if (type.includes('*')) {
        return file.type.startsWith(type.replace('*', ''))
      } else if (type.startsWith('.')) {
        return file.name.toLowerCase().endsWith(type.toLowerCase())
      } else {
        return file.type === type
      }
    })

    if (!isValidType) {
      this.showError(`File "${file.name}" is not an accepted file type`)
      return false
    }

    return true
  }

  addFile(file) {
    const fileObj = {
      file: file,
      id: Date.now() + Math.random(),
      name: file.name,
      size: file.size,
      type: file.type,
      status: 'pending'
    }

    this.files.push(fileObj)
    
    // Create file preview
    if (file.type.startsWith('image/')) {
      this.createImagePreview(fileObj)
    }

    // Upload file if URL is provided
    if (this.uploadUrlValue) {
      this.uploadFile(fileObj)
    }
  }

  createImagePreview(fileObj) {
    const reader = new FileReader()
    reader.onload = (e) => {
      fileObj.preview = e.target.result
      this.updatePreview()
    }
    reader.readAsDataURL(fileObj.file)
  }

  updatePreview() {
    if (!this.hasPreviewTarget) return

    this.previewTarget.innerHTML = ''
    
    this.files.forEach(fileObj => {
      const fileElement = this.createFileElement(fileObj)
      this.previewTarget.appendChild(fileElement)
    })
  }

  createFileElement(fileObj) {
    const div = document.createElement('div')
    div.className = 'flex items-center justify-between p-3 bg-base-100 rounded-lg border'
    div.dataset.fileId = fileObj.id

    const fileInfo = document.createElement('div')
    fileInfo.className = 'flex items-center space-x-3'

    // File icon or preview
    const iconDiv = document.createElement('div')
    iconDiv.className = 'w-10 h-10 rounded bg-base-200 flex items-center justify-center'
    
    if (fileObj.preview) {
      const img = document.createElement('img')
      img.src = fileObj.preview
      img.className = 'w-full h-full object-cover rounded'
      iconDiv.appendChild(img)
    } else {
      // Use phosphor icon based on file type
      const icon = this.getFileIcon(fileObj.type)
      iconDiv.innerHTML = `<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 256 256"><use href="#${icon}"></use></svg>`
    }

    const fileDetails = document.createElement('div')
    fileDetails.innerHTML = `
      <div class="font-medium text-sm">${fileObj.name}</div>
      <div class="text-xs text-base-content/70">${this.formatFileSize(fileObj.size)}</div>
    `

    fileInfo.appendChild(iconDiv)
    fileInfo.appendChild(fileDetails)

    // Status indicator
    const statusDiv = document.createElement('div')
    statusDiv.className = 'flex items-center space-x-2'
    
    if (fileObj.status === 'uploading') {
      statusDiv.innerHTML = '<span class="loading loading-spinner loading-sm"></span>'
    } else if (fileObj.status === 'uploaded') {
      statusDiv.innerHTML = '<div class="badge badge-success badge-sm">Uploaded</div>'
    } else if (fileObj.status === 'error') {
      statusDiv.innerHTML = '<div class="badge badge-error badge-sm">Error</div>'
    }

    // Remove button
    const removeBtn = document.createElement('button')
    removeBtn.type = 'button'
    removeBtn.className = 'btn btn-ghost btn-sm btn-circle'
    removeBtn.innerHTML = '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>'
    removeBtn.addEventListener('click', () => this.removeFile(fileObj.id))

    statusDiv.appendChild(removeBtn)

    div.appendChild(fileInfo)
    div.appendChild(statusDiv)

    return div
  }

  uploadFile(fileObj) {
    const formData = new FormData()
    formData.append('file', fileObj.file)
    formData.append('authenticity_token', this.getCSRFToken())

    fileObj.status = 'uploading'
    this.updateFileStatus(fileObj.id, 'uploading')

    fetch(this.uploadUrlValue, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        fileObj.status = 'uploaded'
        fileObj.uploadedData = data
        this.updateFileStatus(fileObj.id, 'uploaded')
        this.dispatch('fileUploaded', { detail: { file: fileObj, data: data } })
      } else {
        throw new Error(data.error || 'Upload failed')
      }
    })
    .catch(error => {
      fileObj.status = 'error'
      fileObj.error = error.message
      this.updateFileStatus(fileObj.id, 'error')
      this.showError(`Failed to upload ${fileObj.name}: ${error.message}`)
    })
  }

  updateFileStatus(fileId, status) {
    const fileElement = this.previewTarget.querySelector(`[data-file-id="${fileId}"]`)
    if (fileElement) {
      // Update the file element to reflect new status
      this.updatePreview()
    }
  }

  removeFile(fileId) {
    this.files = this.files.filter(file => file.id !== fileId)
    this.updatePreview()
    this.dispatch('fileRemoved', { detail: { fileId } })
  }

  getFileIcon(mimeType) {
    if (mimeType.startsWith('image/')) return 'image'
    if (mimeType === 'application/pdf') return 'file-pdf'
    if (mimeType.includes('word') || mimeType.includes('document')) return 'file-doc'
    if (mimeType.includes('spreadsheet') || mimeType.includes('excel')) return 'file-xls'
    return 'file'
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  showError(message) {
    // Create temporary error alert
    const alert = document.createElement('div')
    alert.className = 'alert alert-error mt-2'
    alert.innerHTML = `<span>${message}</span>`
    
    this.element.appendChild(alert)
    
    setTimeout(() => {
      alert.remove()
    }, 5000)

    this.dispatch('error', { detail: { message } })
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  // Public method to get uploaded files
  getUploadedFiles() {
    return this.files.filter(file => file.status === 'uploaded')
  }

  // Public method to clear all files
  clearFiles() {
    this.files = []
    this.updatePreview()
  }
}