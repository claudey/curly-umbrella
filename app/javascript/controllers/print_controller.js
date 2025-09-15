import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  
  connect() {
    // Add print button if not already present
    this.addPrintButton()
    
    // Add keyboard shortcut (Ctrl+P / Cmd+P)
    this.addKeyboardShortcut()
  }
  
  print() {
    // Prepare for printing
    this.beforePrint()
    
    // Print the page
    window.print()
    
    // Clean up after printing
    this.afterPrint()
  }
  
  printSection() {
    if (this.hasContentTarget) {
      // Create a new window with only the content to print
      const printWindow = window.open('', '_blank')
      const content = this.contentTarget.innerHTML
      
      printWindow.document.write(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Print Document</title>
          <link rel="stylesheet" href="/assets/application.css">
          <style>
            body { margin: 0; padding: 20px; }
            .no-print, .print-button { display: none !important; }
          </style>
        </head>
        <body class="print-mode">
          ${content}
          <script>
            window.onload = function() {
              window.print();
              window.onafterprint = function() {
                window.close();
              };
            };
          </script>
        </body>
        </html>
      `)
      
      printWindow.document.close()
    }
  }
  
  beforePrint() {
    // Add print-mode class to body
    document.body.classList.add('print-mode')
    
    // Hide elements that shouldn't be printed
    this.hideNonPrintElements()
    
    // Expand collapsed sections
    this.expandCollapsedSections()
    
    // Format tables for better printing
    this.formatTablesForPrint()
  }
  
  afterPrint() {
    // Remove print-mode class
    document.body.classList.remove('print-mode')
    
    // Restore hidden elements
    this.restoreNonPrintElements()
    
    // Restore collapsed sections
    this.restoreCollapsedSections()
  }
  
  addPrintButton() {
    if (document.querySelector('[data-print-button]')) return
    
    const printButton = document.createElement('button')
    printButton.className = 'print-button no-print'
    printButton.innerHTML = '<i class="ph ph-printer"></i> Print'
    printButton.setAttribute('data-print-button', 'true')
    printButton.onclick = () => this.print()
    
    // Add to top right of page
    document.body.appendChild(printButton)
  }
  
  addKeyboardShortcut() {
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'p') {
        e.preventDefault()
        this.print()
      }
    })
  }
  
  hideNonPrintElements() {
    this.nonPrintElements = document.querySelectorAll('.no-print, .btn, button:not([data-print-button]), .dropdown, .modal, .alert, .toast')
    this.nonPrintElements.forEach(el => {
      el.style.display = 'none'
    })
  }
  
  restoreNonPrintElements() {
    if (this.nonPrintElements) {
      this.nonPrintElements.forEach(el => {
        el.style.display = ''
      })
    }
  }
  
  expandCollapsedSections() {
    // Expand any collapsed details/summary elements
    this.collapsedDetails = []
    document.querySelectorAll('details:not([open])').forEach(details => {
      this.collapsedDetails.push(details)
      details.setAttribute('open', '')
    })
    
    // Expand any collapsed accordions or similar elements
    document.querySelectorAll('.collapse:not(.collapse-open)').forEach(collapse => {
      collapse.classList.add('collapse-open')
    })
  }
  
  restoreCollapsedSections() {
    // Restore details elements that were originally closed
    if (this.collapsedDetails) {
      this.collapsedDetails.forEach(details => {
        details.removeAttribute('open')
      })
    }
  }
  
  formatTablesForPrint() {
    // Ensure tables fit on page
    document.querySelectorAll('table').forEach(table => {
      if (!table.classList.contains('print-table')) {
        table.classList.add('print-table')
      }
      
      // Add page break avoidance for table rows
      table.querySelectorAll('tr').forEach(row => {
        row.style.pageBreakInside = 'avoid'
      })
    })
  }
  
  // Print specific sections
  printApplication(applicationId) {
    this.printDocument(`/applications/${applicationId}/print`)
  }
  
  printQuote(quoteId) {
    this.printDocument(`/quotes/${quoteId}/print`)
  }
  
  printDocument(url) {
    // Fetch the print version and open in new window
    fetch(url)
      .then(response => response.text())
      .then(html => {
        const printWindow = window.open('', '_blank')
        printWindow.document.write(html)
        printWindow.document.close()
        
        printWindow.onload = () => {
          printWindow.print()
          printWindow.onafterprint = () => printWindow.close()
        }
      })
      .catch(error => {
        console.error('Error fetching print document:', error)
        // Fallback to regular print
        this.print()
      })
  }
  
  // Preview print layout
  togglePrintPreview() {
    document.body.classList.toggle('print-preview')
    
    if (document.body.classList.contains('print-preview')) {
      this.beforePrint()
    } else {
      this.afterPrint()
    }
  }
}