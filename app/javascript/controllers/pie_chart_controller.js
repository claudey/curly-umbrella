import BaseChartController from "./base_chart_controller"
import * as d3 from "d3"

export default class extends BaseChartController {
  static values = { 
    ...BaseChartController.values,
    labelKey: { type: String, default: "label" },
    valueKey: { type: String, default: "value" },
    showLabels: { type: Boolean, default: true },
    showLegend: { type: Boolean, default: true },
    showPercentages: { type: Boolean, default: true },
    animate: { type: Boolean, default: true },
    colorScheme: { type: String, default: "primary" },
    innerRadius: { type: Number, default: 0 }, // For donut charts
    padAngle: { type: Number, default: 0.02 }
  }

  render() {
    if (!this.dataValue || this.dataValue.length === 0) {
      this.renderEmptyState()
      return
    }

    // Parse and prepare data
    const data = this.parseData()
    
    // Calculate chart dimensions
    this.setupDimensions()
    
    // Create pie generator
    this.createPieGenerator()
    
    // Create color scale
    this.colorScale = this.createColorScale(data)
    
    // Create arcs
    this.createArcs(data)
    
    // Add labels if enabled
    if (this.showLabelsValue) {
      this.createLabels(data)
    }
    
    // Add legend if enabled
    if (this.showLegendValue) {
      this.createLegend(data)
    }
    
    // Add interactions
    this.addInteractions(data)
  }

  parseData() {
    return this.dataValue.map(d => ({
      ...d,
      [this.valueKeyValue]: +d[this.valueKeyValue]
    })).filter(d => d[this.valueKeyValue] > 0) // Remove zero values
  }

  setupDimensions() {
    // Calculate available space for pie chart
    const legendWidth = this.showLegendValue ? 150 : 0
    const availableWidth = this.innerWidth - legendWidth
    const availableHeight = this.innerHeight
    
    // Make it a square based on the smaller dimension
    this.radius = Math.min(availableWidth, availableHeight) / 2 - 20
    
    // Center the pie chart
    this.centerX = availableWidth / 2
    this.centerY = this.innerHeight / 2
    
    // Create chart group
    this.pieGroup = this.chart.append("g")
      .attr("class", "pie-chart")
      .attr("transform", `translate(${this.centerX}, ${this.centerY})`)
  }

  createPieGenerator() {
    this.pie = d3.pie()
      .value(d => d[this.valueKeyValue])
      .sort(null) // Maintain data order
      .padAngle(this.padAngleValue)
    
    this.arc = d3.arc()
      .innerRadius(this.innerRadiusValue)
      .outerRadius(this.radius)
    
    this.outerArc = d3.arc()
      .innerRadius(this.radius * 1.1)
      .outerRadius(this.radius * 1.1)
  }

  createArcs(data) {
    const pieData = this.pie(data)
    const tooltip = this.createTooltip()
    
    // Create arc paths
    const paths = this.pieGroup.selectAll(".arc")
      .data(pieData)
      .enter()
      .append("g")
      .attr("class", "arc")
    
    const arcPaths = paths.append("path")
      .attr("fill", (d, i) => this.colorScale(i))
      .attr("stroke", "#ffffff")
      .attr("stroke-width", 2)
      .style("cursor", "pointer")
    
    // Add hover effects and tooltips
    arcPaths
      .on("mouseover", (event, d) => {
        d3.select(event.currentTarget)
          .transition()
          .duration(200)
          .attr("transform", () => {
            const centroid = this.arc.centroid(d)
            return `translate(${centroid[0] * 0.1}, ${centroid[1] * 0.1})`
          })
          .style("filter", "brightness(110%)")
        
        const percentage = ((d.data[this.valueKeyValue] / d3.sum(data, d => d[this.valueKeyValue])) * 100).toFixed(1)
        const content = `
          <div>
            <div style="font-weight: bold;">${d.data[this.labelKeyValue]}</div>
            <div>${this.formatValue(d.data[this.valueKeyValue])}</div>
            <div style="font-size: 11px; opacity: 0.8;">${percentage}% of total</div>
          </div>
        `
        this.showTooltip(tooltip, content, event)
      })
      .on("mouseout", (event, d) => {
        d3.select(event.currentTarget)
          .transition()
          .duration(200)
          .attr("transform", "translate(0, 0)")
          .style("filter", "none")
        
        this.hideTooltip(tooltip)
      })
    
    // Animate arcs
    if (this.animateValue) {
      arcPaths
        .attr("d", this.arc)
        .transition()
        .delay((d, i) => i * 200)
        .duration(800)
        .ease(d3.easeBackOut)
        .attrTween("d", (d) => {
          const interpolate = d3.interpolate({ startAngle: 0, endAngle: 0 }, d)
          return (t) => this.arc(interpolate(t))
        })
    } else {
      arcPaths.attr("d", this.arc)
    }
    
    return paths
  }

  createLabels(data) {
    const pieData = this.pie(data)
    const total = d3.sum(data, d => d[this.valueKeyValue])
    
    // Create label groups
    const labels = this.pieGroup.selectAll(".label")
      .data(pieData)
      .enter()
      .append("g")
      .attr("class", "label")
    
    // Add label lines for external labels
    const labelLines = labels.append("polyline")
      .attr("fill", "none")
      .attr("stroke", "#666")
      .attr("stroke-width", 1)
      .style("opacity", 0.7)
    
    // Add label text
    const labelTexts = labels.append("text")
      .attr("font-size", "11px")
      .attr("font-weight", "500")
      .attr("fill", "#374151")
      .style("text-anchor", d => this.midAngle(d) < Math.PI ? "start" : "end")
    
    // Position labels
    this.positionLabels(pieData, labelLines, labelTexts, total)
    
    // Animate labels
    if (this.animateValue) {
      labels
        .style("opacity", 0)
        .transition()
        .delay(800)
        .duration(500)
        .style("opacity", 1)
    }
  }

  positionLabels(pieData, labelLines, labelTexts, total) {
    const minSliceAngle = 0.15 // Don't show labels for very small slices
    
    labelLines.attr("points", d => {
      if (d.endAngle - d.startAngle < minSliceAngle) return ""
      
      const posA = this.arc.centroid(d)
      const posB = this.outerArc.centroid(d)
      const posC = this.outerArc.centroid(d)
      posC[0] = this.radius * 0.95 * (this.midAngle(d) < Math.PI ? 1 : -1)
      return [posA, posB, posC]
    })
    
    labelTexts
      .attr("transform", d => {
        if (d.endAngle - d.startAngle < minSliceAngle) return "translate(0, -1000)" // Hide
        
        const pos = this.outerArc.centroid(d)
        pos[0] = this.radius * 0.95 * (this.midAngle(d) < Math.PI ? 1 : -1)
        return `translate(${pos})`
      })
      .text(d => {
        if (d.endAngle - d.startAngle < minSliceAngle) return ""
        
        const percentage = ((d.data[this.valueKeyValue] / total) * 100).toFixed(1)
        const label = d.data[this.labelKeyValue]
        
        if (this.showPercentagesValue) {
          return `${label} (${percentage}%)`
        }
        return label
      })
  }

  createLegend(data) {
    const legendWidth = 140
    const legendX = this.innerWidth - legendWidth + 20
    
    const legend = this.chart.append("g")
      .attr("class", "legend")
      .attr("transform", `translate(${legendX}, 20)`)
    
    const legendItems = legend.selectAll(".legend-item")
      .data(data)
      .enter()
      .append("g")
      .attr("class", "legend-item")
      .attr("transform", (d, i) => `translate(0, ${i * 20})`)
      .style("cursor", "pointer")
    
    // Legend color boxes
    legendItems.append("rect")
      .attr("width", 12)
      .attr("height", 12)
      .attr("fill", (d, i) => this.colorScale(i))
      .attr("stroke", "#ffffff")
      .attr("stroke-width", 1)
    
    // Legend text
    legendItems.append("text")
      .attr("x", 18)
      .attr("y", 6)
      .attr("dy", "0.35em")
      .attr("font-size", "11px")
      .attr("fill", "#374151")
      .text(d => {
        const label = d[this.labelKeyValue]
        return label.length > 15 ? label.substring(0, 12) + "..." : label
      })
    
    // Add legend interactions
    legendItems
      .on("mouseover", (event, d) => {
        // Highlight corresponding arc
        this.pieGroup.selectAll(".arc path")
          .style("opacity", arc => arc.data[this.labelKeyValue] === d[this.labelKeyValue] ? 1 : 0.3)
      })
      .on("mouseout", () => {
        this.pieGroup.selectAll(".arc path").style("opacity", 1)
      })
    
    // Animate legend
    if (this.animateValue) {
      legendItems
        .style("opacity", 0)
        .transition()
        .delay((d, i) => i * 100 + 1000)
        .duration(300)
        .style("opacity", 1)
    }
  }

  addInteractions(data) {
    // Add click interactions
    this.pieGroup.selectAll(".arc")
      .on("click", (event, d) => {
        // Dispatch custom event for external handling
        const customEvent = new CustomEvent('slice-clicked', {
          detail: { data: d.data, originalEvent: event }
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

  midAngle(d) {
    return d.startAngle + (d.endAngle - d.startAngle) / 2
  }

  formatValue(value) {
    if (Math.abs(value) >= 1000) {
      return this.formatCurrency(value)
    }
    return this.formatNumber(value)
  }

  renderEmptyState() {
    const emptyGroup = this.chart.append("g")
      .attr("class", "empty-state")
      .attr("transform", `translate(${this.innerWidth / 2}, ${this.innerHeight / 2})`)
    
    // Empty state circle
    emptyGroup.append("circle")
      .attr("r", 60)
      .attr("fill", "none")
      .attr("stroke", "#E5E7EB")
      .attr("stroke-width", 2)
      .attr("stroke-dasharray", "5,5")
    
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