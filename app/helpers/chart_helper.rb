module ChartHelper
  def chart_container(type, data, options = {}, &block)
    # Set default options
    default_options = {
      width: 800,
      height: 400,
      responsive: true,
      animate: true,
      class: "chart-container",
      data: { controller: "#{type.to_s.gsub('_', '-')}-chart" }
    }
    
    # Merge provided options
    merged_options = default_options.deep_merge(options)
    
    # Extract CSS classes
    css_classes = [merged_options.delete(:class)].flatten.compact.join(' ')
    
    # Set up data attributes for Stimulus
    data_attributes = merged_options.delete(:data) || {}
    data_attributes["#{type.to_s.gsub('_', '-')}-chart-data-value"] = data.to_json
    
    # Add other chart options as data attributes
    chart_options = %w[width height responsive animate x_key y_key label_key value_key 
                       show_grid show_labels show_legend show_points show_values 
                       orientation color_scheme curve fill_opacity gradient 
                       inner_radius pad_angle margin]
    
    chart_options.each do |option|
      key = option.to_sym
      data_key = option.gsub('_', '-')
      if merged_options.key?(key)
        data_attributes["#{type.to_s.gsub('_', '-')}-chart-#{data_key}-value"] = merged_options[key]
      end
    end
    
    # Build the container
    content_tag :div, class: css_classes, data: data_attributes do
      if block_given?
        capture(&block)
      else
        # Default loading state
        content_tag :div, class: "chart-loading" do
          "Loading chart..."
        end
      end
    end
  end

  def line_chart(data, options = {})
    chart_container(:line_chart, data, options)
  end

  def bar_chart(data, options = {})
    chart_container(:bar_chart, data, options)
  end

  def pie_chart(data, options = {})
    chart_container(:pie_chart, data, options)
  end

  def area_chart(data, options = {})
    chart_container(:area_chart, data, options)
  end

  # Chart data formatting helpers
  def format_chart_data(records, x_field, y_field, options = {})
    records.map do |record|
      {
        x_field.to_sym => extract_field_value(record, x_field),
        y_field.to_sym => extract_field_value(record, y_field)
      }.merge(options[:extra_fields] || {})
    end
  end

  def format_time_series_data(records, date_field, value_field, options = {})
    period = options[:period] || :day
    
    grouped_data = case period
    when :day
      records.group_by_day(date_field, format: "%Y-%m-%d")
    when :week
      records.group_by_week(date_field, format: "%Y-%m-%d")
    when :month
      records.group_by_month(date_field, format: "%Y-%m")
    when :year
      records.group_by_year(date_field, format: "%Y")
    else
      records.group_by_day(date_field, format: "%Y-%m-%d")
    end

    aggregation = options[:aggregation] || :count
    
    result = case aggregation
    when :count
      grouped_data.count
    when :sum
      grouped_data.sum(value_field)
    when :average
      grouped_data.average(value_field)
    when :maximum
      grouped_data.maximum(value_field)
    when :minimum
      grouped_data.minimum(value_field)
    else
      grouped_data.count
    end

    result.map do |date, value|
      {
        date: date.is_a?(String) ? date : date.strftime("%Y-%m-%d"),
        value: value.to_f
      }
    end
  end

  def format_distribution_data(records, group_field, value_field = nil, options = {})
    if value_field
      # Sum values by group
      records.group(group_field).sum(value_field).map do |group, value|
        {
          label: format_group_label(group),
          value: value.to_f
        }
      end
    else
      # Count records by group
      records.group(group_field).count.map do |group, count|
        {
          label: format_group_label(group),
          value: count.to_f
        }
      end
    end
  end

  def format_comparison_data(records, category_field, value_field, options = {})
    aggregation = options[:aggregation] || :sum
    
    result = case aggregation
    when :count
      records.group(category_field).count
    when :sum
      records.group(category_field).sum(value_field)
    when :average
      records.group(category_field).average(value_field)
    when :maximum
      records.group(category_field).maximum(value_field)
    when :minimum
      records.group(category_field).minimum(value_field)
    else
      records.group(category_field).sum(value_field)
    end

    result.map do |category, value|
      {
        label: format_group_label(category),
        value: value.to_f
      }
    end
  end

  # Chart title and description helpers
  def chart_title_and_subtitle(title, subtitle = nil, options = {})
    content_tag :div, class: "chart-header" do
      concat content_tag(:h3, title, class: "chart-title")
      if subtitle.present?
        concat content_tag(:p, subtitle, class: "chart-subtitle")
      end
    end
  end

  def dashboard_chart_grid(columns: 2, &block)
    css_class = "dashboard-charts grid-#{columns}"
    content_tag :div, class: css_class, &block
  end

  # Chart configuration presets
  def currency_chart_options(base_options = {})
    {
      y_key: 'value',
      show_grid: true,
      animate: true,
      responsive: true
    }.merge(base_options)
  end

  def percentage_chart_options(base_options = {})
    {
      y_key: 'value',
      show_grid: true,
      show_percentages: true,
      animate: true,
      responsive: true
    }.merge(base_options)
  end

  def timeline_chart_options(base_options = {})
    {
      x_key: 'date',
      y_key: 'value',
      show_grid: true,
      show_points: true,
      animate: true,
      responsive: true,
      curve: 'curveMonotoneX'
    }.merge(base_options)
  end

  private

  def extract_field_value(record, field)
    if field.is_a?(Symbol) || field.is_a?(String)
      record.respond_to?(field) ? record.send(field) : record[field]
    elsif field.is_a?(Proc)
      field.call(record)
    else
      field
    end
  end

  def format_group_label(group)
    case group
    when String
      group.humanize
    when Symbol
      group.to_s.humanize
    when Date, Time
      group.strftime("%b %d, %Y")
    when Numeric
      group.to_s
    when nil
      "Unknown"
    else
      group.to_s.humanize
    end
  end
end