import BaseChartController from "./base_chart_controller"
import * as d3 from "d3"

export default class extends BaseChartController {
  static values = { 
    ...BaseChartController.values,
    xKey: { type: String, default: "label" },
    yKey: { type: String, default: "value" },
    orientation: { type: String, default: "vertical" }, // 'vertical' or 'horizontal'
    showValues: { type: Boolean, default: true },
    showGrid: { type: Boolean, default: true },
    animate: { type: Boolean, default: true },
    colorScheme: { type: String, default: "primary" }
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
    this.createAxes(data)
    
    // Create bars
    this.createBars(data)
    
    // Add value labels if enabled
    if (this.showValuesValue) {
      this.createValueLabels(data)
    }
    
    // Add interactions
    this.addInteractions(data)
  }

  parseData() {
    return this.dataValue.map(d => ({
      ...d,
      [this.yKeyValue]: +d[this.yKeyValue]
    }))
  }

  createScales(data) {
    const isVertical = this.orientationValue === 'vertical'
    
    if (isVertical) {
      // X scale for categories
      this.xScale = d3.scaleBand()
        .domain(data.map(d => d[this.xKeyValue]))
        .range([0, this.innerWidth])
        .padding(0.2)
      
      // Y scale for values
      const yExtent = d3.extent(data, d => d[this.yKeyValue])
      const yMax = yExtent[1]
      const yMin = Math.min(0, yExtent[0])
      
      this.yScale = d3.scaleLinear()
        .domain([yMin, yMax * 1.1]) // Add 10% padding to top
        .range([this.innerHeight, 0])
    } else {
      // Horizontal orientation
      this.xScale = d3.scaleLinear()
        .domain([0, d3.max(data, d => d[this.yKeyValue]) * 1.1])
        .range([0, this.innerWidth])
      
      this.yScale = d3.scaleBand()
        .domain(data.map(d => d[this.xKeyValue]))
        .range([0, this.innerHeight])
        .padding(0.2)
    }
  }

  createAxes(data) {
    const isVertical = this.orientationValue === 'vertical'
    
    if (isVertical) {
      // X Axis (categories)
      const xAxis = d3.axisBottom(this.xScale)
        .tickSizeOuter(0)
      
      this.chart.append("g")
        .attr("class", "x-axis")
        .attr("transform", `translate(0, ${this.innerHeight})`)
        .call(xAxis)
        .selectAll("text")
        .style("font-size", "12px")
        .style("fill", "#6B7280")
        .style("text-anchor", "middle")
        .call(this.wrapText, this.xScale.bandwidth())
      
      // Y Axis (values)
      const yAxis = d3.axisLeft(this.yScale)
        .ticks(6)
        .tickFormat(d => this.formatYValue(d))
      
      this.chart.append("g")
        .attr("class", "y-axis")
        .call(yAxis)
        .selectAll("text")
        .style("font-size", "12px")
        .style("fill", "#6B7280")
    } else {
      // Horizontal orientation
      const xAxis = d3.axisBottom(this.xScale)
        .ticks(6)
        .tickFormat(d => this.formatYValue(d))
      
      this.chart.append("g")
        .attr("class", "x-axis")
        .attr("transform", `translate(0, ${this.innerHeight})`)
        .call(xAxis)
        .selectAll("text")
        .style("font-size", "12px")
        .style("fill", "#6B7280")
      
      const yAxis = d3.axisLeft(this.yScale)
        .tickSizeOuter(0)
      
      this.chart.append("g")
        .attr("class", "y-axis")
        .call(yAxis)
        .selectAll("text")
        .style("font-size", "12px")
        .style("fill", "#6B7280")
        .call(this.wrapText, 100)
    }
    
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
    const isVertical = this.orientationValue === 'vertical'
    
    if (isVertical) {
      // Horizontal grid lines
      this.chart.append("g")
        .attr("class", "grid")
        .call(d3.axisLeft(this.yScale)
          .ticks(6)
          .tickSize(-this.innerWidth)
          .tickFormat("")
        )
        .selectAll("line")
        .style("stroke", "#F3F4F6")
        .style("stroke-dasharray", "2,2")
    } else {
      // Vertical grid lines
      this.chart.append("g")
        .attr("class", "grid")
        .attr("transform", `translate(0, ${this.innerHeight})`)
        .call(d3.axisBottom(this.xScale)
          .ticks(6)
          .tickSize(-this.innerHeight)
          .tickFormat("")
        )
        .selectAll("line")
        .style("stroke", "#F3F4F6")
        .style("stroke-dasharray", "2,2")
    }
    
    this.chart.selectAll(".grid .domain").style("display", "none")
  }

  createBars(data) {
    const isVertical = this.orientationValue === 'vertical'
    const colorScale = this.createColorScale(data)
    const tooltip = this.createTooltip()
    
    const bars = this.chart.selectAll(".bar")
      .data(data)
      .enter()
      .append("rect")
      .attr("class", "bar")
      .style("cursor", "pointer")
    
    if (isVertical) {
      bars
        .attr("x", d => this.xScale(d[this.xKeyValue]))
        .attr("width", this.xScale.bandwidth())
        .attr("y", this.innerHeight)
        .attr("height", 0)
        .attr("fill", (d, i) => colorScale(i))
    } else {
      bars
        .attr("x", 0)
        .attr("width", 0)
        .attr("y", d => this.yScale(d[this.xKeyValue]))
        .attr("height", this.yScale.bandwidth())
        .attr("fill", (d, i) => colorScale(i))
    }
    
    // Add hover effects and tooltips
    bars
      .on("mouseover", (event, d) => {
        d3.select(event.currentTarget)
          .transition()
          .duration(200)
          .style("opacity", 0.8)
        
        const content = `
          <div>
            <div style="font-weight: bold;">${d[this.xKeyValue]}</div>
            <div>${this.formatYValue(d[this.yKeyValue])}</div>
          </div>
        `
        this.showTooltip(tooltip, content, event)
      })
      .on("mouseout", (event) => {
        d3.select(event.currentTarget)
          .transition()
          .duration(200)
          .style("opacity", 1)
        
        this.hideTooltip(tooltip)
      })
    
    // Animate bars
    if (this.animateValue) {
      if (isVertical) {
        bars
          .transition()
          .delay((d, i) => i * 100)
          .duration(800)
          .ease(d3.easeBackOut.overshoot(1))
          .attr("y", d => this.yScale(Math.max(0, d[this.yKeyValue])))
          .attr("height", d => Math.abs(this.yScale(d[this.yKeyValue]) - this.yScale(0)))
      } else {
        bars
          .transition()
          .delay((d, i) => i * 100)
          .duration(800)
          .ease(d3.easeBackOut.overshoot(1))
          .attr("width", d => this.xScale(Math.max(0, d[this.yKeyValue])))
      }
    } else {
      if (isVertical) {
        bars
          .attr("y", d => this.yScale(Math.max(0, d[this.yKeyValue])))
          .attr("height", d => Math.abs(this.yScale(d[this.yKeyValue]) - this.yScale(0)))
      } else {
        bars
          .attr("width", d => this.xScale(Math.max(0, d[this.yKeyValue])))
      }
    }
  }

  createValueLabels(data) {
    const isVertical = this.orientationValue === 'vertical'
    
    const labels = this.chart.selectAll(".value-label")
      .data(data)
      .enter()
      .append("text")
      .attr("class", "value-label")
      .style("font-size", "11px")
      .style("font-weight", "500")
      .style("fill", "#374151")
      .style("text-anchor", "middle")
      .style("pointer-events", "none")
    
    if (isVertical) {
      labels
        .attr("x", d => this.xScale(d[this.xKeyValue]) + this.xScale.bandwidth() / 2)
        .attr("y", d => this.yScale(Math.max(0, d[this.yKeyValue])) - 5)
        .text(d => this.formatYValue(d[this.yKeyValue]))
    } else {
      labels
        .attr("x", d => this.xScale(Math.max(0, d[this.yKeyValue])) + 5)
        .attr("y", d => this.yScale(d[this.xKeyValue]) + this.yScale.bandwidth() / 2 + 4)
        .style("text-anchor", "start")
        .text(d => this.formatYValue(d[this.yKeyValue]))
    }
    
    // Animate labels
    if (this.animateValue) {
      labels
        .style("opacity", 0)
        .transition()
        .delay((d, i) => i * 100 + 400)
        .duration(300)
        .style("opacity", 1)
    }
  }

  addInteractions(data) {
    // Add click interactions if needed
    this.chart.selectAll(".bar")
      .on("click", (event, d) => {
        // Dispatch custom event for external handling
        const customEvent = new CustomEvent('bar-clicked', {
          detail: { data: d, originalEvent: event }
        })
        this.element.dispatchEvent(customEvent)
      })
  }

  createColorScale(data) {
    const colors = this.getColorScheme(this.colorSchemeValue)
    return d3.scaleOrdinal()
      .domain(d3.range(data.length))
      .range(colors)
  }

  formatYValue(value) {
    if (Math.abs(value) >= 1000) {
      return this.formatCurrency(value)
    }
    return this.formatNumber(value)
  }

  // Utility function to wrap long text labels
  wrapText(text, width) {
    text.each(function() {
      const text = d3.select(this)
      const words = text.text().split(/\s+/).reverse()
      let word
      let line = []
      let lineNumber = 0
      const lineHeight = 1.1
      const y = text.attr("y")
      const dy = parseFloat(text.attr("dy")) || 0
      let tspan = text.text(null).append("tspan").attr("x", 0).attr("y", y).attr("dy", dy + "em")
      
      while (word = words.pop()) {
        line.push(word)
        tspan.text(line.join(" "))
        if (tspan.node().getComputedTextLength() > width) {
          line.pop()
          tspan.text(line.join(" "))
          line = [word]
          tspan = text.append("tspan")
            .attr("x", 0)
            .attr("y", y)
            .attr("dy", ++lineNumber * lineHeight + dy + "em")
            .text(word)
        }
      }
    })
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