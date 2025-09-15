import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["table", "tbody", "search", "row"]
  static values = { id: String }

  connect() {
    this.originalRows = Array.from(this.rowTargets)
    this.currentSort = { column: null, direction: 'asc' }
  }

  search(event) {
    const searchTerm = event.target.value.toLowerCase()
    
    this.rowTargets.forEach(row => {
      const text = row.textContent.toLowerCase()
      const shouldShow = text.includes(searchTerm)
      
      row.style.display = shouldShow ? '' : 'none'
    })
  }

  sort(event) {
    const column = event.currentTarget.dataset.column
    
    // Toggle sort direction
    if (this.currentSort.column === column) {
      this.currentSort.direction = this.currentSort.direction === 'asc' ? 'desc' : 'asc'
    } else {
      this.currentSort.column = column
      this.currentSort.direction = 'asc'
    }

    this.applySorting(column, this.currentSort.direction)
    this.updateSortIcons(column, this.currentSort.direction)
  }

  applySorting(column, direction) {
    const columnIndex = this.getColumnIndex(column)
    if (columnIndex === -1) return

    const sortedRows = Array.from(this.rowTargets).sort((a, b) => {
      const aValue = this.getCellValue(a, columnIndex)
      const bValue = this.getCellValue(b, columnIndex)
      
      return this.compareValues(aValue, bValue, direction)
    })

    // Remove all rows
    this.rowTargets.forEach(row => row.remove())
    
    // Add sorted rows back
    sortedRows.forEach(row => this.tbodyTarget.appendChild(row))
  }

  getColumnIndex(column) {
    const headers = this.tableTarget.querySelectorAll('th')
    for (let i = 0; i < headers.length; i++) {
      if (headers[i].dataset.column === column) {
        return i
      }
    }
    return -1
  }

  getCellValue(row, columnIndex) {
    const cell = row.cells[columnIndex]
    if (!cell) return ''
    
    // Try to extract numeric value first
    const text = cell.textContent.trim()
    const numericValue = text.replace(/[^\d.-]/g, '')
    
    if (numericValue && !isNaN(parseFloat(numericValue))) {
      return parseFloat(numericValue)
    }
    
    return text.toLowerCase()
  }

  compareValues(a, b, direction) {
    let result = 0
    
    if (typeof a === 'number' && typeof b === 'number') {
      result = a - b
    } else {
      result = a.toString().localeCompare(b.toString())
    }
    
    return direction === 'desc' ? -result : result
  }

  updateSortIcons(activeColumn, direction) {
    // Update all sort icons
    const headers = this.tableTarget.querySelectorAll('th[data-column]')
    
    headers.forEach(header => {
      const icon = header.querySelector('svg')
      if (!icon) return
      
      const column = header.dataset.column
      
      if (column === activeColumn) {
        // Update active column icon
        this.updateIconForDirection(icon, direction)
        header.classList.add('bg-base-300')
      } else {
        // Reset other column icons
        this.updateIconForDirection(icon, null)
        header.classList.remove('bg-base-300')
      }
    })
  }

  updateIconForDirection(icon, direction) {
    // Remove existing classes
    icon.classList.remove('rotate-180', 'opacity-50')
    
    if (direction === 'desc') {
      icon.classList.add('rotate-180')
    } else if (direction === null) {
      icon.classList.add('opacity-50')
    }
  }

  // Method to refresh table data (for AJAX updates)
  refresh(newRowsHTML) {
    this.tbodyTarget.innerHTML = newRowsHTML
    this.originalRows = Array.from(this.rowTargets)
  }

  // Method to add a new row
  addRow(rowHTML) {
    this.tbodyTarget.insertAdjacentHTML('beforeend', rowHTML)
    this.originalRows = Array.from(this.rowTargets)
  }

  // Method to remove a row
  removeRow(rowIndex) {
    const row = this.rowTargets[rowIndex]
    if (row) {
      row.remove()
      this.originalRows = Array.from(this.rowTargets)
    }
  }

  // Method to update a specific row
  updateRow(rowIndex, newRowHTML) {
    const row = this.rowTargets[rowIndex]
    if (row) {
      row.outerHTML = newRowHTML
      this.originalRows = Array.from(this.rowTargets)
    }
  }
}