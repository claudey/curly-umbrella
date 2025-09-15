import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = { 
    data: Array,
    width: { type: Number, default: 800 },
    height: { type: Number, default: 400 },
    margin: { type: Object, default: { top: 20, right: 30, bottom: 40, left: 50 } },
    responsive: { type: Boolean, default: true }
  }

  connect() {
    this.setupChart()
    this.render()
    
    if (this.responsiveValue) {
      this.setupResponsive()
    }
  }

  setupChart() {
    // Clear any existing SVG
    d3.select(this.element).selectAll("*").remove()
    
    // Create responsive container
    this.container = d3.select(this.element)
      .style("width", "100%")
      .style("height", "auto")
    
    // Calculate dimensions
    this.containerWidth = this.element.clientWidth || this.widthValue
    this.containerHeight = this.heightValue
    
    this.innerWidth = this.containerWidth - this.marginValue.left - this.marginValue.right
    this.innerHeight = this.containerHeight - this.marginValue.top - this.marginValue.bottom
    
    // Create SVG
    this.svg = this.container
      .append("svg")
      .attr("viewBox", `0 0 ${this.containerWidth} ${this.containerHeight}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("height", "auto")
    
    // Create chart group with margins
    this.chart = this.svg
      .append("g")
      .attr("transform", `translate(${this.marginValue.left}, ${this.marginValue.top})`)
  }

  setupResponsive() {
    this.resizeObserver = new ResizeObserver(entries => {
      for (let entry of entries) {
        this.handleResize()
      }
    })
    
    this.resizeObserver.observe(this.element)
    
    // Also listen for window resize as fallback
    this.boundResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.boundResize)
  }

  handleResize() {
    // Debounce resize events
    clearTimeout(this.resizeTimeout)
    this.resizeTimeout = setTimeout(() => {
      const newWidth = this.element.clientWidth
      if (newWidth !== this.containerWidth && newWidth > 0) {
        this.setupChart()
        this.render()
      }
    }, 150)
  }

  render() {
    // Override in subclasses
    throw new Error("render() method must be implemented in subclass")
  }

  // Utility methods for common chart operations
  createTooltip() {
    return d3.select("body")
      .append("div")
      .attr("class", "chart-tooltip")
      .style("position", "absolute")
      .style("visibility", "hidden")
      .style("background-color", "rgba(0, 0, 0, 0.8)")
      .style("color", "white")
      .style("padding", "8px 12px")
      .style("border-radius", "4px")
      .style("font-size", "12px")
      .style("pointer-events", "none")
      .style("z-index", "1000")
  }

  showTooltip(tooltip, content, event) {
    tooltip
      .style("visibility", "visible")
      .html(content)
      .style("left", (event.pageX + 10) + "px")
      .style("top", (event.pageY - 10) + "px")
  }

  hideTooltip(tooltip) {
    tooltip.style("visibility", "hidden")
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value)
  }

  formatNumber(value) {
    return new Intl.NumberFormat('en-US').format(value)
  }

  formatPercent(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'percent',
      minimumFractionDigits: 1,
      maximumFractionDigits: 1
    }).format(value / 100)
  }

  // Color schemes
  getColorScheme(type = 'categorical') {
    const schemes = {
      categorical: d3.schemeSet3,
      sequential: d3.schemeBlues[9],
      diverging: d3.schemeRdBu[11],
      primary: ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#F97316", "#06B6D4", "#84CC16"],
      pastel: ["#93C5FD", "#86EFAC", "#FDE68A", "#FCA5A5", "#C4B5FD", "#FDBA74", "#67E8F9", "#BEF264"]
    }
    return schemes[type] || schemes.categorical
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    
    if (this.boundResize) {
      window.removeEventListener('resize', this.boundResize)
    }
    
    // Clear any timeouts
    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout)
    }
    
    // Remove any tooltips
    d3.selectAll(".chart-tooltip").remove()
  }
}