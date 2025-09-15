import BaseChartController from "./base_chart_controller"
import * as d3 from "d3"

export default class extends BaseChartController {
  static values = { 
    ...BaseChartController.values,
    xKey: { type: String, default: "date" },
    yKey: { type: String, default: "value" },
    showPoints: { type: Boolean, default: true },
    showGrid: { type: Boolean, default: true },
    animate: { type: Boolean, default: true },
    curve: { type: String, default: "curveMonotoneX" }
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
    
    // Create axes
    this.createAxes()
    
    // Create line
    this.createLine(data)
    
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
    }))
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
    
    // Add padding to y domain
    const yPadding = (yDomain[1] - yDomain[0]) * 0.1
    yDomain[0] = Math.max(0, yDomain[0] - yPadding)
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
      .tickFormat(d => this.formatNumber(d))
    
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
      .attr("stroke", "#3B82F6")
      .attr("stroke-width", 3)
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
        .duration(1500)
        .ease(d3.easeLinear)
        .attr("stroke-dashoffset", 0)
    }
    
    // Add hover effects
    linePath
      .on("mouseover", () => linePath.style("stroke-width", 4))
      .on("mouseout", () => linePath.style("stroke-width", 3))
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
      .attr("fill", "#3B82F6")
      .attr("stroke", "#FFFFFF")
      .attr("stroke-width", 2)
      .style("cursor", "pointer")
    
    // Animate points
    if (this.animateValue) {
      points
        .transition()
        .delay((d, i) => i * 100)
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
    // Add focus line for better interaction
    const focusLine = this.chart.append("line")
      .attr("class", "focus-line")
      .attr("y1", 0)
      .attr("y2", this.innerHeight)
      .style("stroke", "#6B7280")
      .style("stroke-width", 1)
      .style("stroke-dasharray", "3,3")
      .style("opacity", 0)
    
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
        }
      })
      .on("mouseleave", () => {
        focusLine.style("opacity", 0)
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
    
    emptyGroup.append("text")
      .attr("text-anchor", "middle")
      .attr("dy", "-10px")
      .style("font-size", "16px")
      .style("fill", "#9CA3AF")
      .style("font-weight", "500")
      .text("No data available")
    
    emptyGroup.append("text")
      .attr("text-anchor", "middle")
      .attr("dy", "15px")
      .style("font-size", "12px")
      .style("fill", "#9CA3AF")
      .text("Data will appear here when available")
  }
}