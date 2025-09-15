import BaseChartController from "./base_chart_controller"
import * as d3 from "d3"

export default class extends BaseChartController {
  static values = { 
    ...BaseChartController.values,
    xKey: { type: String, default: "date" },
    yKey: { type: String, default: "value" },
    showLine: { type: Boolean, default: true },
    showPoints: { type: Boolean, default: false },
    showGrid: { type: Boolean, default: true },
    animate: { type: Boolean, default: true },
    curve: { type: String, default: "curveMonotoneX" },
    fillOpacity: { type: Number, default: 0.3 },
    gradient: { type: Boolean, default: true }
  }

  render() {
    if (!this.dataValue || this.dataValue.length === 0) {
      this.renderEmptyState()
      return
    }

    // Parse data
    const data = this.parseData()
    
    // Create scales
    this.createScales(data)
    
    // Create gradient definitions
    if (this.gradientValue) {
      this.createGradient()
    }
    
    // Create axes
    this.createAxes()
    
    // Create area
    this.createArea(data)
    
    // Create line if enabled
    if (this.showLineValue) {
      this.createLine(data)
    }
    
    // Create points if enabled
    if (this.showPointsValue) {
      this.createPoints(data)
    }
    
    // Add interactions
    this.addInteractions(data)
  }

  parseData() {
    return this.dataValue.map(d => ({
      ...d,
      [this.xKeyValue]: this.parseXValue(d[this.xKeyValue]),
      [this.yKeyValue]: +d[this.yKeyValue]
    })).sort((a, b) => {
      // Sort by x value to ensure proper area rendering
      if (a[this.xKeyValue] instanceof Date && b[this.xKeyValue] instanceof Date) {
        return a[this.xKeyValue] - b[this.xKeyValue]
      }
      return a[this.xKeyValue] - b[this.xKeyValue]
    })
  }

  parseXValue(value) {
    // Try to parse as date first
    if (typeof value === 'string' && (value.includes('-') || value.includes('/'))) {
      const parsed = new Date(value)
      if (!isNaN(parsed)) return parsed
    }
    return value
  }

  createScales(data) {
    const xDomain = d3.extent(data, d => d[this.xKeyValue])
    const yDomain = d3.extent(data, d => d[this.yKeyValue])
    
    // Extend y domain to start at 0 for area charts
    yDomain[0] = 0
    
    // Add padding to y domain
    const yPadding = yDomain[1] * 0.1
    yDomain[1] = yDomain[1] + yPadding
    
    // Determine scale type based on data
    this.xScale = this.isDateData(data) 
      ? d3.scaleTime().domain(xDomain).range([0, this.innerWidth])
      : d3.scaleLinear().domain(xDomain).range([0, this.innerWidth])
    
    this.yScale = d3.scaleLinear()
      .domain(yDomain)
      .range([this.innerHeight, 0])
  }

  isDateData(data) {
    return data.length > 0 && data[0][this.xKeyValue] instanceof Date
  }

  createGradient() {
    const defs = this.svg.append("defs")
    
    const gradient = defs.append("linearGradient")
      .attr("id", `area-gradient-${this.element.id || 'default'}`)
      .attr("gradientUnits", "userSpaceOnUse")
      .attr("x1", 0).attr("y1", 0)
      .attr("x2", 0).attr("y2", this.innerHeight)
    
    gradient.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "#3B82F6")
      .attr("stop-opacity", this.fillOpacityValue)
    
    gradient.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "#3B82F6")
      .attr("stop-opacity", 0.05)
  }

  createAxes() {
    // X Axis
    const xAxisFormat = this.isDateData(this.parseData()) 
      ? d3.timeFormat("%b %d")
      : d3.format(".0f")
    
    const xAxis = d3.axisBottom(this.xScale)
      .ticks(Math.min(6, this.dataValue.length))
      .tickFormat(xAxisFormat)
    
    this.chart.append("g")
      .attr("class", "x-axis")
      .attr("transform", `translate(0, ${this.innerHeight})`)
      .call(xAxis)
      .selectAll("text")
      .style("font-size", "12px")
      .style("fill", "#6B7280")
    
    // Y Axis
    const yAxis = d3.axisLeft(this.yScale)
      .ticks(6)
      .tickFormat(d => this.formatYValue(d))
    
    this.chart.append("g")
      .attr("class", "y-axis")
      .call(yAxis)
      .selectAll("text")
      .style("font-size", "12px")
      .style("fill", "#6B7280")
    
    // Grid lines
    if (this.showGridValue) {
      this.createGrid()
    }
    
    // Style axis lines
    this.chart.selectAll(".domain")
      .style("stroke", "#E5E7EB")
      .style("stroke-width", 1)
    
    this.chart.selectAll(".tick line")
      .style("stroke", "#E5E7EB")
      .style("stroke-width", 1)
  }

  createGrid() {
    // Horizontal grid lines
    this.chart.append("g")
      .attr("class", "grid grid-horizontal")
      .call(d3.axisLeft(this.yScale)
        .ticks(6)
        .tickSize(-this.innerWidth)
        .tickFormat("")
      )
      .selectAll("line")
      .style("stroke", "#F3F4F6")
      .style("stroke-dasharray", "2,2")
    
    // Vertical grid lines
    this.chart.append("g")
      .attr("class", "grid grid-vertical")
      .attr("transform", `translate(0, ${this.innerHeight})`)
      .call(d3.axisBottom(this.xScale)
        .ticks(Math.min(6, this.dataValue.length))
        .tickSize(-this.innerHeight)
        .tickFormat("")
      )
      .selectAll("line")
      .style("stroke", "#F3F4F6")
      .style("stroke-dasharray", "2,2")
    
    // Hide grid domain
    this.chart.selectAll(".grid .domain").style("display", "none")
  }

  createArea(data) {
    // Define area generator
    const area = d3.area()
      .x(d => this.xScale(d[this.xKeyValue]))
      .y0(this.yScale(0))
      .y1(d => this.yScale(d[this.yKeyValue]))
      .curve(d3[this.curveValue] || d3.curveMonotoneX)
    
    // Create area path
    const areaPath = this.chart.append("path")
      .datum(data)
      .attr("class", "area")
      .attr("fill", this.gradientValue ? `url(#area-gradient-${this.element.id || 'default'})` : "#3B82F6")
      .attr("fill-opacity", this.gradientValue ? 1 : this.fillOpacityValue)
      .attr("d", area)
    
    // Animate area
    if (this.animateValue) {
      // Create clip path for animation
      const clipPath = this.svg.append("defs")
        .append("clipPath")
        .attr("id", `clip-${this.element.id || 'default'}`)
      
      const clipRect = clipPath.append("rect")
        .attr("width", 0)
        .attr("height", this.containerHeight)
        .attr("x", this.marginValue.left)
        .attr("y", 0)
      
      // Apply clip path
      areaPath.attr("clip-path", `url(#clip-${this.element.id || 'default'})`)
      
      // Animate clip path
      clipRect
        .transition()
        .duration(2000)
        .ease(d3.easeLinear)
        .attr("width", this.containerWidth)
    }
    
    // Add hover effects
    areaPath
      .on("mouseover", () => {
        areaPath.transition()
          .duration(200)
          .attr("fill-opacity", this.gradientValue ? 1 : Math.min(1, this.fillOpacityValue + 0.1))
      })
      .on("mouseout", () => {
        areaPath.transition()
          .duration(200)
          .attr("fill-opacity", this.gradientValue ? 1 : this.fillOpacityValue)
      })
  }

  createLine(data) {
    // Define line generator
    const line = d3.line()
      .x(d => this.xScale(d[this.xKeyValue]))
      .y(d => this.yScale(d[this.yKeyValue]))
      .curve(d3[this.curveValue] || d3.curveMonotoneX)
    
    // Create line path
    const linePath = this.chart.append("path")
      .datum(data)
      .attr("class", "line")
      .attr("fill", "none")
      .attr("stroke", "#1E40AF")
      .attr("stroke-width", 2)
      .attr("stroke-linejoin", "round")
      .attr("stroke-linecap", "round")
      .attr("d", line)
    
    // Animate line drawing
    if (this.animateValue) {
      const totalLength = linePath.node().getTotalLength()
      
      linePath
        .attr("stroke-dasharray", `${totalLength} ${totalLength}`)
        .attr("stroke-dashoffset", totalLength)
        .transition()
        .delay(500)
        .duration(1500)
        .ease(d3.easeLinear)
        .attr("stroke-dashoffset", 0)
    }
  }

  createPoints(data) {
    const tooltip = this.createTooltip()
    
    const points = this.chart.selectAll(".point")
      .data(data)
      .enter()
      .append("circle")
      .attr("class", "point")
      .attr("cx", d => this.xScale(d[this.xKeyValue]))
      .attr("cy", d => this.yScale(d[this.yKeyValue]))
      .attr("r", 0)
      .attr("fill", "#1E40AF")
      .attr("stroke", "#FFFFFF")
      .attr("stroke-width", 2)
      .style("cursor", "pointer")
    
    // Animate points
    if (this.animateValue) {
      points
        .transition()
        .delay((d, i) => i * 50 + 1000)
        .duration(300)
        .attr("r", 4)
    } else {
      points.attr("r", 4)
    }
    
    // Add hover interactions
    points
      .on("mouseover", (event, d) => {
        d3.select(event.currentTarget)
          .transition()
          .duration(200)
          .attr("r", 6)
        
        const content = `
          <div>
            <div style="font-weight: bold;">${this.formatXValue(d[this.xKeyValue])}</div>
            <div>${this.formatYValue(d[this.yKeyValue])}</div>
          </div>
        `
        this.showTooltip(tooltip, content, event)
      })
      .on("mouseout", (event) => {
        d3.select(event.currentTarget)
          .transition()
          .duration(200)
          .attr("r", 4)
        
        this.hideTooltip(tooltip)
      })
  }

  addInteractions(data) {
    // Add focus line and interactive overlay
    const focusLine = this.chart.append("line")
      .attr("class", "focus-line")
      .attr("y1", 0)
      .attr("y2", this.innerHeight)
      .style("stroke", "#6B7280")
      .style("stroke-width", 1)
      .style("stroke-dasharray", "3,3")
      .style("opacity", 0)
    
    const focusCircle = this.chart.append("circle")
      .attr("class", "focus-circle")
      .attr("r", 4)
      .attr("fill", "#1E40AF")
      .attr("stroke", "#FFFFFF")
      .attr("stroke-width", 2)
      .style("opacity", 0)
    
    const tooltip = this.createTooltip()
    
    // Add invisible overlay for mouse tracking
    this.chart.append("rect")
      .attr("class", "overlay")
      .attr("width", this.innerWidth)
      .attr("height", this.innerHeight)
      .style("fill", "none")
      .style("pointer-events", "all")
      .on("mousemove", (event) => {
        const [mouseX] = d3.pointer(event)
        const x0 = this.xScale.invert(mouseX)
        
        // Find closest data point
        const bisector = d3.bisector(d => d[this.xKeyValue]).left
        const i = bisector(data, x0, 1)
        const d0 = data[i - 1]
        const d1 = data[i]
        
        if (d0 && d1) {
          const d = x0 - d0[this.xKeyValue] > d1[this.xKeyValue] - x0 ? d1 : d0
          
          focusLine
            .attr("x1", this.xScale(d[this.xKeyValue]))
            .attr("x2", this.xScale(d[this.xKeyValue]))
            .style("opacity", 0.7)
          
          focusCircle
            .attr("cx", this.xScale(d[this.xKeyValue]))
            .attr("cy", this.yScale(d[this.yKeyValue]))
            .style("opacity", 1)
          
          const content = `
            <div>
              <div style="font-weight: bold;">${this.formatXValue(d[this.xKeyValue])}</div>
              <div>${this.formatYValue(d[this.yKeyValue])}</div>
            </div>
          `
          this.showTooltip(tooltip, content, event)
        }
      })
      .on("mouseleave", () => {
        focusLine.style("opacity", 0)
        focusCircle.style("opacity", 0)
        this.hideTooltip(tooltip)
      })
  }

  formatXValue(value) {
    if (value instanceof Date) {
      return d3.timeFormat("%b %d, %Y")(value)
    }
    return this.formatNumber(value)
  }

  formatYValue(value) {
    // Check if value looks like currency (based on magnitude)
    if (value >= 1000) {
      return this.formatCurrency(value)
    }
    return this.formatNumber(value)
  }

  renderEmptyState() {
    const emptyGroup = this.chart.append("g")
      .attr("class", "empty-state")
      .attr("transform", `translate(${this.innerWidth / 2}, ${this.innerHeight / 2})`)
    
    // Create a simple area shape for empty state
    const emptyArea = d3.area()
      .x(d => d.x)
      .y0(20)
      .y1(d => d.y)
      .curve(d3.curveCardinal)
    
    const emptyData = [
      { x: -60, y: -10 },
      { x: -20, y: -20 },
      { x: 20, y: -5 },
      { x: 60, y: -15 }
    ]
    
    emptyGroup.append("path")
      .datum(emptyData)
      .attr("d", emptyArea)
      .attr("fill", "#E5E7EB")
      .attr("opacity", 0.5)
    
    emptyGroup.append("text")
      .attr("text-anchor", "middle")
      .attr("dy", "40px")
      .style("font-size", "16px")
      .style("fill", "#9CA3AF")
      .style("font-weight", "500")
      .text("No data available")
    
    emptyGroup.append("text")
      .attr("text-anchor", "middle")
      .attr("dy", "65px")
      .style("font-size", "12px")
      .style("fill", "#9CA3AF")
      .text("Data will appear here when available")
  }
}