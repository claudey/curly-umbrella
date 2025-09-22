import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = [
    "query", "scope", "perPage", "suggestions", "results", "loading",
    "filtersPanel", "filtersToggle", "filterContent"
  ]

  connect() {
    this.debounceTimer = null
    this.currentRequest = null
    this.filtersVisible = false
    
    // Load recent searches if query is empty
    if (!this.queryTarget.value.trim()) {
      this.loadHistory()
    }
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.currentRequest) {
      this.currentRequest.abort()
    }
  }

  // Input handling with debouncing
  onInput(event) {
    const query = event.target.value.trim()
    
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    
    if (query.length >= 2) {
      this.debounceTimer = setTimeout(() => {
        this.loadSuggestions(query)
      }, 300)
    } else {
      this.hideSuggestions()
    }
  }

  // Keyboard navigation
  onKeydown(event) {
    switch (event.key) {
      case 'Enter':
        event.preventDefault()
        this.hideSuggestions()
        this.performSearch()
        break
      case 'Escape':
        this.hideSuggestions()
        break
      case 'ArrowDown':
        event.preventDefault()
        this.navigateSuggestions('down')
        break
      case 'ArrowUp':
        event.preventDefault()
        this.navigateSuggestions('up')
        break
    }
  }

  // Scope change handling
  onScopeChange() {
    if (this.queryTarget.value.trim()) {
      this.performSearch()
    }
    this.loadFilters()
  }

  // Main search function
  async performSearch() {
    const query = this.queryTarget.value.trim()
    
    if (!query) {
      this.showEmptyState()
      return
    }

    this.showLoading()
    this.hideSuggestions()

    try {
      const params = new URLSearchParams({
        query: query,
        scope: this.scopeTarget.value,
        per_page: this.perPageTarget.value,
        page: 1
      })

      // Add filters if any are active
      const filters = this.getActiveFilters()
      if (Object.keys(filters).length > 0) {
        params.append('filters', JSON.stringify(filters))
      }

      const response = await fetch(`${this.urlValue}?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      this.displayResults(data)
      this.saveSearch(data.total_count)
      
    } catch (error) {
      console.error('Search error:', error)
      this.showError()
    } finally {
      this.hideLoading()
    }
  }

  // Pagination
  async goToPage(event) {
    const page = event.target.dataset.page
    await this.performSearchWithPage(page)
  }

  async performSearchWithPage(page) {
    const query = this.queryTarget.value.trim()
    
    if (!query) return

    this.showLoading()

    try {
      const params = new URLSearchParams({
        query: query,
        scope: this.scopeTarget.value,
        per_page: this.perPageTarget.value,
        page: page
      })

      const filters = this.getActiveFilters()
      if (Object.keys(filters).length > 0) {
        params.append('filters', JSON.stringify(filters))
      }

      const response = await fetch(`${this.urlValue}?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      const data = await response.json()
      this.displayResults(data)
      
    } catch (error) {
      console.error('Pagination error:', error)
      this.showError()
    } finally {
      this.hideLoading()
    }
  }

  // Suggestions
  async loadSuggestions(query) {
    if (this.currentRequest) {
      this.currentRequest.abort()
    }

    try {
      const params = new URLSearchParams({ query: query })
      
      this.currentRequest = fetch(`${this.urlValue}/suggestions?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      const response = await this.currentRequest
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      this.displaySuggestions(data.suggestions)
      
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Suggestions error:', error)
      }
    }
  }

  displaySuggestions(suggestions) {
    const suggestionsContainer = this.suggestionsTarget.querySelector('.dropdown-content')
    
    if (!suggestions || suggestions.length === 0) {
      this.hideSuggestions()
      return
    }

    suggestionsContainer.innerHTML = suggestions.map((suggestion, index) => {
      return `
        <li>
          <a href="#" class="suggestion-item ${index === 0 ? 'active' : ''}" 
             data-action="click->search#selectSuggestion"
             data-value="${suggestion.value}"
             data-label="${suggestion.label}">
            <div class="flex justify-between items-center w-full">
              <span>${suggestion.label}</span>
              <span class="badge badge-sm badge-outline">${suggestion.category}</span>
            </div>
          </a>
        </li>
      `
    }).join('')

    this.showSuggestions()
  }

  selectSuggestion(event) {
    event.preventDefault()
    const label = event.currentTarget.dataset.label
    this.queryTarget.value = label
    this.hideSuggestions()
    this.performSearch()
  }

  navigateSuggestions(direction) {
    const items = this.suggestionsTarget.querySelectorAll('.suggestion-item')
    if (items.length === 0) return

    const activeItem = this.suggestionsTarget.querySelector('.suggestion-item.active')
    let nextIndex = 0

    if (activeItem) {
      const currentIndex = Array.from(items).indexOf(activeItem)
      if (direction === 'down') {
        nextIndex = (currentIndex + 1) % items.length
      } else {
        nextIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1
      }
      activeItem.classList.remove('active')
    }

    items[nextIndex].classList.add('active')
    items[nextIndex].scrollIntoView({ block: 'nearest' })
  }

  showSuggestions() {
    this.suggestionsTarget.classList.remove('hidden')
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add('hidden')
  }

  // Filters
  toggleFilters() {
    this.filtersVisible = !this.filtersVisible
    
    if (this.filtersVisible) {
      this.filtersPanelTarget.classList.remove('hidden')
      this.filtersToggleTarget.checked = true
      this.loadFilters()
    } else {
      this.filtersPanelTarget.classList.add('hidden')
      this.filtersToggleTarget.checked = false
    }
  }

  async loadFilters() {
    if (!this.filtersVisible) return

    try {
      const params = new URLSearchParams({
        query: this.queryTarget.value || '',
        scope: this.scopeTarget.value
      })

      const response = await fetch(`/search/filters?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      const data = await response.json()
      this.displayFilters(data.filters)
      
    } catch (error) {
      console.error('Filter loading error:', error)
    }
  }

  displayFilters(filters) {
    const scope = this.scopeTarget.value
    let filtersHtml = ''

    if (scope === 'all' || scope === 'clients') {
      filtersHtml += this.buildFilterSection('Clients', filters.clients)
    }
    if (scope === 'all' || scope === 'applications') {
      filtersHtml += this.buildFilterSection('Applications', filters.applications)
    }
    if (scope === 'all' || scope === 'quotes') {
      filtersHtml += this.buildFilterSection('Quotes', filters.quotes)
    }
    if (scope === 'all' || scope === 'documents') {
      filtersHtml += this.buildFilterSection('Documents', filters.documents)
    }

    this.filterContentTarget.innerHTML = filtersHtml
  }

  buildFilterSection(title, sectionFilters) {
    if (!sectionFilters || Object.keys(sectionFilters).length === 0) {
      return ''
    }

    let html = `<div class="mb-6"><h4 class="font-semibold mb-3">${title}</h4><div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">`

    Object.entries(sectionFilters).forEach(([filterType, options]) => {
      if (options && options.length > 0) {
        html += `
          <div class="form-control">
            <label class="label">
              <span class="label-text capitalize">${filterType.replace('_', ' ')}</span>
            </label>
            <select class="select select-sm select-bordered" data-filter-type="${filterType}" data-action="change->search#onFilterChange">
              <option value="">All</option>
              ${options.map(option => `
                <option value="${option.value}">${option.label} (${option.count})</option>
              `).join('')}
            </select>
          </div>
        `
      }
    })

    html += '</div></div>'
    return html
  }

  onFilterChange() {
    if (this.queryTarget.value.trim()) {
      this.performSearch()
    }
  }

  getActiveFilters() {
    const filters = {}
    const filterSelects = this.filterContentTarget.querySelectorAll('select[data-filter-type]')
    
    filterSelects.forEach(select => {
      if (select.value) {
        filters[select.dataset.filterType] = select.value
      }
    })

    return filters
  }

  // History management
  selectRecentSearch(event) {
    const query = event.target.dataset.query
    this.queryTarget.value = query
    this.performSearch()
  }

  async clearHistory() {
    try {
      const response = await fetch(`${this.urlValue}/clear_history`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        // Remove history section from UI
        const historyCard = document.querySelector('.card:has(.card-title:contains("Recent Searches"))')
        if (historyCard) {
          historyCard.remove()
        }
      }
    } catch (error) {
      console.error('Clear history error:', error)
    }
  }

  async loadHistory() {
    try {
      const response = await fetch(`${this.urlValue}/history`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      const data = await response.json()
      // History is loaded on page load, so we don't need to update UI here
      
    } catch (error) {
      console.error('History loading error:', error)
    }
  }

  async saveSearch(resultsCount) {
    try {
      await fetch(`${this.urlValue}/save`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          query: this.queryTarget.value,
          results_count: resultsCount
        })
      })
    } catch (error) {
      console.error('Save search error:', error)
      // Fail silently for analytics
    }
  }

  // UI state management
  showLoading() {
    this.loadingTarget.classList.remove('hidden')
    this.resultsTarget.classList.add('hidden')
  }

  hideLoading() {
    this.loadingTarget.classList.add('hidden')
    this.resultsTarget.classList.remove('hidden')
  }

  displayResults(data) {
    this.resultsTarget.innerHTML = data.html
    
    // Update URL without page reload
    const url = new URL(window.location)
    url.searchParams.set('query', this.queryTarget.value)
    url.searchParams.set('scope', this.scopeTarget.value)
    window.history.pushState({}, '', url)
  }

  showError() {
    this.resultsTarget.innerHTML = `
      <div class="card bg-base-100 shadow-lg">
        <div class="card-body text-center">
          <div class="text-6xl mb-4 text-error">⚠️</div>
          <h3 class="text-xl font-semibold mb-2 text-error">Search Error</h3>
          <p class="text-base-content/70 mb-4">
            We encountered an issue while searching. Please try again in a moment.
          </p>
          <button class="btn btn-primary" data-action="click->search#retry">
            Try Again
          </button>
        </div>
      </div>
    `
  }

  showEmptyState() {
    this.resultsTarget.innerHTML = `
      <div class="card bg-base-100 shadow-lg">
        <div class="card-body text-center">
          <div class="text-6xl mb-4">🔍</div>
          <h3 class="text-xl font-semibold mb-2">Start searching</h3>
          <p class="text-base-content/70">Enter a search term above to find clients, applications, quotes, and documents</p>
        </div>
      </div>
    `
  }

  retry() {
    this.performSearch()
  }

  clearSearch() {
    this.queryTarget.value = ''
    this.showEmptyState()
    this.hideSuggestions()
    
    // Update URL
    const url = new URL(window.location)
    url.searchParams.delete('query')
    url.searchParams.delete('scope')
    window.history.pushState({}, '', url)
  }
}